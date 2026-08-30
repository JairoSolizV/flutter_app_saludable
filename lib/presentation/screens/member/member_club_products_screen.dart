import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../providers/product_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/order_item_option.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/club_membership.dart';
import '../../../domain/entities/combo.dart';
import '../../../domain/entities/combo_cart_item.dart';
import '../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../data/datasources/remote/combo_remote_data_source.dart';
import '../../widgets/product_image.dart';
import '../../../domain/entities/product_option_selection.dart';
import 'member_product_detail_screen.dart';
import 'member_combo_detail_screen.dart';
import 'widgets/member_cart_checkout.dart';
import 'package:flutter_app_saludable/core/orders/order_offline_messages.dart';
import 'package:flutter_app_saludable/core/orders/order_submit_outcome.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/bolivian_price.dart';
import 'package:flutter_app_saludable/core/utils/order_item_options_display.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';

class MemberClubProductsScreen extends StatefulWidget {
  final int clubId;
  final String clubNombre;

  const MemberClubProductsScreen({
    super.key,
    required this.clubId,
    required this.clubNombre,
  });

  @override
  State<MemberClubProductsScreen> createState() =>
      _MemberClubProductsScreenState();
}

class _MemberClubProductsScreenState extends State<MemberClubProductsScreen> {
  // ── Cart ──
  final Map<String, int> _cart = {};
  final Map<String, String> _productNotes = {};
  final Map<String, List<ProductOptionSelection>> _cartSelections = {};
  final Map<String, Product> _cartProducts = {};
  final Map<String, ComboCartItem> _comboCart = {};

  // ── Membership / loading ──
  ClubMembership? _membership;
  bool _isLoadingMembership = true;
  bool _isCreatingOrder = false;

  // ── Combos ──
  List<Combo> _combos = [];
  bool _isLoadingCombos = false;

  // ── Order options ──
  String _tipoConsumo = 'EN_LUGAR';
  final TextEditingController _notaController = TextEditingController();

  // ═══════════════════════ LIFECYCLE ═══════════════════════

  @override
  void initState() {
    super.initState();
    _loadMembershipAndProducts();
  }

  @override
  void dispose() {
    _notaController.dispose();
    super.dispose();
  }

  // ═══════════════════════ DATA LOADING ═══════════════════════

  Future<void> _loadMembershipAndProducts() async {
    try {
      final user =
          Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user == null) {
        setState(() => _isLoadingMembership = false);
        return;
      }

      final membresiaDs =
          Provider.of<MembresiaRemoteDataSource>(context, listen: false);
      final membresias =
          await membresiaDs.getMembresiasPorUsuario(int.parse(user.id));

      if (membresias.isNotEmpty) {
        setState(() {
          _membership = membresias.first;
          _isLoadingMembership = false;
        });
        if (mounted) {
          await Provider.of<ProductProvider>(context, listen: false)
              .loadAvailableProducts(widget.clubId);
          _loadCombos();
        }
      } else {
        setState(() => _isLoadingMembership = false);
      }
    } catch (e) {
      debugPrint('Error loading membership: $e');
      if (mounted) setState(() => _isLoadingMembership = false);
    }
  }

  /// Recarga productos, combos y sabores del club. Usado por pull-to-refresh.
  Future<void> _refreshProducts() async {
    await Provider.of<ProductProvider>(context, listen: false)
        .loadAvailableProducts(widget.clubId);
    await _loadCombos();
  }

  Future<void> _loadCombos() async {
    setState(() => _isLoadingCombos = true);
    try {
      final ds = Provider.of<ComboRemoteDataSource>(context, listen: false);
      final result = await ds.getCombosByClub(widget.clubId);
      if (mounted) {
        setState(() {
          _combos = result.where((c) => c.activo).toList();
          _isLoadingCombos = false;
        });
      }
    } catch (e) {
      debugPrint('[MEMBER] Error cargando combos: $e');
      if (mounted) setState(() => _isLoadingCombos = false);
    }
  }

  Map<String, Product> _productsById() {
    final products =
        Provider.of<ProductProvider>(context, listen: false).products;
    return {for (final p in products) p.id: p};
  }

  // ═══════════════════════ CART HELPERS ═══════════════════════

  void _updateQuantity(String productId, int delta) {
    setState(() {
      _adjustCartKey(productId, delta, productId: productId);
    });
  }

  void _adjustCartKey(String key, int delta, {required String productId}) {
    final next = ((_cart[key] ?? 0) + delta).clamp(0, 99);
    if (next > 0) {
      _cart[key] = next;
    } else {
      _cart.remove(key);
      _productNotes.remove(key);
      _cartSelections.remove(key);
      final hasAny = _cart.keys.any((k) =>
          k == productId ||
          k.startsWith('$productId#'));
      if (!hasAny) {
        _cartProducts.remove(productId);
      }
    }
  }

  void _adjustComboQuantity(String configKey, int delta) {
    final existing = _comboCart[configKey];
    if (existing == null) return;
    final next = (existing.quantity + delta).clamp(0, 99);
    if (next > 0) {
      _comboCart[configKey] = existing.copyWith(quantity: next);
    } else {
      _comboCart.remove(configKey);
    }
  }

  int _qtyForProduct(Product product) {
    var n = 0;
    for (final e in _cart.entries) {
      if (e.key == product.id ||
          e.key.startsWith('${product.id}_') ||
          e.key.startsWith('${product.id}#')) {
        n += e.value;
      }
    }
    return n;
  }

  Future<void> _onProductPlus(Product product) async {
    await _openProductDetail(product);
  }

  Future<void> _openProductDetail(Product product) async {
    final result = await Navigator.of(context).push<ProductCartAddResult>(
      MaterialPageRoute(
        builder: (_) => MemberProductDetailScreen(product: product),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final key = result.cartKey;
      _cart[key] = (_cart[key] ?? 0) + result.quantity;
      _cartSelections[key] = result.selections;
      _cartProducts[product.id] = product;
    });
  }

  void _onProductMinus(Product product) {
    final hashKeys =
        _cart.keys.where((k) => k.startsWith('${product.id}#')).toList();
    if (hashKeys.isNotEmpty) {
      setState(() => _adjustCartKey(hashKeys.last, -1, productId: product.id));
      return;
    }
    if (product.hasConfigurableOptionGroups) return;
    _updateQuantity(product.id, -1);
  }

  String _productIdFromCartKey(String key) {
    if (key.contains('#')) return key.split('#').first;
    return key.split('_').first;
  }

  String? _configuredSummary(Product product) {
    final lines = _cart.entries
        .where((e) =>
            (e.key == product.id ||
                e.key.startsWith('${product.id}_') ||
                e.key.startsWith('${product.id}#')) &&
            e.value > 0)
        .toList();
    if (lines.isEmpty) return null;
    final labels = <String>[];
    for (final e in lines) {
      final sels = _cartSelections[e.key];
      final options = sels?.map((s) => s.toOrderItemOption()).toList() ??
          const <OrderItemOption>[];
      final optionsText = OrderItemOptionsDisplay.compactSummary(options);
      final unit = product?.effectivePrice ?? 0;
      final priced = product?.hasConfiguredSalePrice == true;
      labels.add(optionsText.isEmpty
          ? (priced
              ? '${e.value} × ${BolivianPrice.formatBs(unit)}'
              : '${e.value} u.')
          : '$optionsText · ${priced ? '${e.value} × ${BolivianPrice.formatBs(unit)}' : '${e.value} u.'}');
    }
    if (labels.isEmpty) return null;
    return labels.join(' · ');
  }

  Product? _lookupProduct(String productId) {
    final cached = _cartProducts[productId];
    if (cached != null) return cached;
    try {
      return Provider.of<ProductProvider>(context, listen: false)
          .products
          .firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  int get _totalItems => MemberCartTotals.totalUnits(
        productCart: _cart,
        comboCart: _comboCart.values,
      );

  double get _cartTotalAmount => MemberCartTotals.totalAmount(
        productCart: _cart,
        unitPriceFor: (pid) => _lookupProduct(pid)?.effectivePrice ?? 0,
        isPriced: (pid) => _lookupProduct(pid)?.hasConfiguredSalePrice == true,
        comboCart: _comboCart.values,
      );

  List<MemberCartLineViewModel> _cartLineViewModels() {
    final lines = _cart.entries.map((e) {
      final pid = _productIdFromCartKey(e.key);
      final product = _lookupProduct(pid);
      final sels = _cartSelections[e.key] ?? const [];
      final options = sels.map((s) => s.toOrderItemOption()).toList();
      return MemberCartLineViewModel(
        cartKey: e.key,
        productId: pid,
        productName: product?.name ?? 'Producto',
        optionsSummary: OrderItemOptionsDisplay.compactSummary(options),
        quantity: e.value,
        unitPrice: product?.effectivePrice ?? 0,
        priced: product?.hasConfiguredSalePrice == true,
      );
    }).toList();

    lines.addAll(_comboCart.entries.map((e) {
      final combo = e.value;
      return MemberCartLineViewModel(
        cartKey: e.key,
        productId: combo.comboId.toString(),
        productName: combo.comboName,
        optionsSummary: '',
        quantity: combo.quantity,
        unitPrice: combo.price,
        priced: combo.hasConfiguredPrice,
        isCombo: true,
        comboComponentLines: combo.componentSummaryLines(),
      );
    }));

    return lines;
  }

  void _clearCart() {
    _cart.clear();
    _cartSelections.clear();
    _cartProducts.clear();
    _productNotes.clear();
    _comboCart.clear();
  }

  String _buildItemNote(String cartKey) {
    final n = _productNotes[cartKey];
    return n ?? '';
  }

  Future<void> _openComboDetail(Combo combo) async {
    if (!combo.hasConfiguredPrice) return;
    final result = await Navigator.of(context).push<ComboCartItem>(
      MaterialPageRoute(
        builder: (_) => MemberComboDetailScreen(
          combo: combo,
          productsById: _productsById(),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final key = result.configKey;
      final existing = _comboCart[key];
      if (existing != null) {
        _comboCart[key] = existing.copyWith(
          quantity: existing.quantity + result.quantity,
        );
      } else {
        _comboCart[key] = result;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Combo "${combo.nombre}" agregado'),
        backgroundColor: AppTheme.success,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  // ═══════════════════════ NOTE DIALOG ═══════════════════════

  void _showNoteDialog(String cartKey, String productName) {
    final ctrl = TextEditingController(text: _productNotes[cartKey] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.fileText,
                  color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Nota para $productName',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ej: Sin azucar, extra hielo...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    final t = ctrl.text.trim();
                    if (t.isEmpty) {
                      _productNotes.remove(cartKey);
                    } else {
                      _productNotes[cartKey] = t;
                    }
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Guardar nota'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════ CREATE ORDER ═══════════════════════

  Future<bool> _createOrder() async {
    if (_isCreatingOrder) return false;
    if (_cart.isEmpty && _comboCart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecciona al menos un producto o combo'),
          backgroundColor: Colors.orange));
      return false;
    }
    if (_membership == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No tienes una membresia activa'),
          backgroundColor: Colors.red));
      return false;
    }

    setState(() => _isCreatingOrder = true);
    try {
      final user =
          Provider.of<UserProvider>(context, listen: false).currentUser!;
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      final orderId = const Uuid().v4();

      final items = <OrderItem>[];
      for (final e in _cart.entries) {
        final pid = _productIdFromCartKey(e.key);
        final product = _lookupProduct(pid);
        final selections = _cartSelections[e.key] ?? const [];
        if (product?.hasConfigurableOptionGroups == true) {
          if (selections.isEmpty) {
            throw Exception(
              'Completa la configuración de ${product!.name} antes de pedir.',
            );
          }
          for (final s in selections) {
            if (!s.hasRequiredIds) {
              throw Exception(
                'Configuración incompleta en ${product!.name}. '
                'Vuelve a abrir el producto y elige las opciones.',
              );
            }
          }
        }
        items.add(OrderItem(
          orderId: orderId,
          productId: pid,
          quantity: e.value,
          note: _buildItemNote(e.key),
          productName: product?.name ?? '',
          options: selections.map((s) => s.toOrderItemOption()).toList(),
        ));
      }

      final combos =
          _comboCart.values.map((c) => c.toOrderCombo(orderId)).toList();

      final outcome = await orderProv.createOrder(OrderEntity(
        id: orderId,
        userId: user.id,
        clubId: widget.clubId,
        membresiaId: _membership!.id,
        tipoConsumo: _tipoConsumo,
        observaciones: _notaController.text.trim(),
        status: 'pending',
        createdAt: DateTime.now(),
        items: items,
        combos: combos,
        isSynced: false,
      ));

      if (mounted) {
        setState(_clearCart);
        context.go('/member-orders');
        final snackText = outcome == OrderSubmitOutcome.remoteSynced
            ? OrderOfflineMessages.sentSynced
            : OrderOfflineMessages.savedPending;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(snackText),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ));
      }
      return true;
    } catch (e) {
      if (mounted) {
        final err = e.toString();
        String msg = err.replaceAll('Exception: ', '');
        if (err.contains('inactiva') || err.contains('no activa')) {
          msg = 'Tu membresia no esta activa. Contacta al anfitrion.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }
  }

  void _openCartSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.5,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return StatefulBuilder(
              builder: (context, sheetSetState) {
                void refreshSheet() {
                  setState(() {});
                  sheetSetState(() {});
                }

                return MemberCartCheckoutSheet(
                  lines: _cartLineViewModels(),
                  totalAmount: _cartTotalAmount,
                  tipoConsumo: _tipoConsumo,
                  onTipoConsumoChanged: (v) {
                    setState(() => _tipoConsumo = v);
                    sheetSetState(() {});
                  },
                  notaController: _notaController,
                  scrollController: scrollController,
                  isCreatingOrder: _isCreatingOrder,
                  onQuantityChanged: (key, delta) {
                    setState(() {
                      if (key.startsWith('combo:')) {
                        _adjustComboQuantity(key, delta);
                      } else {
                        _adjustCartKey(
                          key,
                          delta,
                          productId: _productIdFromCartKey(key),
                        );
                      }
                    });
                    if (_cart.isEmpty && _comboCart.isEmpty) {
                      Navigator.pop(sheetContext);
                    } else {
                      refreshSheet();
                    }
                  },
                  onRemoveLine: (key) {
                    setState(() {
                      if (key.startsWith('combo:')) {
                        _comboCart.remove(key);
                      } else {
                        final qty = _cart[key] ?? 0;
                        _adjustCartKey(
                          key,
                          -qty,
                          productId: _productIdFromCartKey(key),
                        );
                      }
                    });
                    if (_cart.isEmpty && _comboCart.isEmpty) {
                      Navigator.pop(sheetContext);
                    } else {
                      refreshSheet();
                    }
                  },
                  onCreateOrder: () async {
                    final ok = await _createOrder();
                    if (ok && sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    } else if (mounted) {
                      sheetSetState(() {});
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  //                         BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final provProducts = Provider.of<ProductProvider>(context);
    final products = provProducts.products;
    final isLoading = provProducts.isLoading;

    if (_isLoadingMembership) {
      return Scaffold(
          appBar: _appBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_membership == null) {
      return Scaffold(
        appBar: _appBar(),
        body: RefreshableScrollView(
          onRefresh: _loadMembershipAndProducts,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.userX, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'No tienes una membresia activa.\nDebes ser socio de un club para hacer pedidos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _appBar(),
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty && _combos.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _refreshProducts,
                        color: AppTheme.primaryColor,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            _totalItems > 0 ? 88 : 16,
                          ),
                          children: [
                            // ── COMBOS ──
                            if (_combos.isNotEmpty) ...[
                              _sectionHeader(LucideIcons.zap,
                                  'Combos disponibles',
                                  '${_combos.length} combo${_combos.length > 1 ? 's' : ''}'),
                              const SizedBox(height: 8),
                              ..._combos.map(_comboCard),
                              const SizedBox(height: 20),
                            ],
                            // ── PRODUCTS ──
                            if (products.isNotEmpty) ...[
                              _sectionHeader(LucideIcons.cupSoda, 'Productos',
                                  '${products.length} disponible${products.length > 1 ? 's' : ''}'),
                              const SizedBox(height: 8),
                              ...products.map(_productCard),
                            ],
                          ],
                        ),
                      ),
          ),
          if (_totalItems > 0)
            MemberCartBar(
              totalUnits: _totalItems,
              totalAmount: _cartTotalAmount,
              onTap: _openCartSheet,
            ),
        ],
      ),
    );
  }

  // ─────────── AppBar ───────────

  PreferredSizeWidget _appBar() => AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Productos', style: TextStyle(fontSize: 18)),
            Text(widget.clubNombre,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      );

  // ─────────── Section header ───────────

  Widget _sectionHeader(IconData icon, String title, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                if (subtitle != null)
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
              ]),
        ),
      ]),
    );
  }

  // ═══════════════════════ COMBO CARD ═══════════════════════

  Widget _comboCard(Combo combo) {
    final purchasable = combo.hasConfiguredPrice;
    final inCartQty = _comboCart.values
        .where((c) => c.comboId == combo.id)
        .fold(0, (sum, c) => sum + c.quantity);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.25)),
      ),
      color: AppTheme.primaryColor.withOpacity(0.04),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: purchasable ? () => _openComboDetail(combo) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppTheme.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.zap, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      combo.nombre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      combo.itemsSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      purchasable
                          ? BolivianPrice.formatBs(combo.price)
                          : 'Precio no configurado',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: purchasable
                            ? AppTheme.primaryColor
                            : Colors.orange.shade800,
                      ),
                    ),
                    if (combo.puntosValor > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${combo.puntosValor} puntos',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (inCartQty > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$inCartQty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (purchasable)
                Icon(LucideIcons.chevronRight, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════ PRODUCT CARD ═══════════════════════

  Widget _productCard(Product product) {
    final cartKey = product.id;
    final qty = _qtyForProduct(product);
    final hasNote = _productNotes.containsKey(cartKey);
    final inCart = qty > 0;
    final configuredSummary = _configuredSummary(product);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: inCart ? 3 : 1,
      shadowColor:
          inCart ? AppTheme.primaryColor.withOpacity(0.3) : Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: inCart
            ? const BorderSide(color: AppTheme.primaryColor, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openProductDetail(product),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: image + info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductImage(
                  imageUrl:
                      product.imageUrl.isEmpty ? null : product.imageUrl,
                  width: 60,
                  height: 60,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      if (product.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(product.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                      if (product.puntosValor > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${product.puntosValor} pts',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor)),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        BolivianPrice.label(product.effectivePrice),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: product.hasConfiguredSalePrice
                              ? Colors.black87
                              : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (configuredSummary != null) ...[
              const SizedBox(height: 8),
              Text(
                configuredSummary,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],

            // Quantity + note row
            const SizedBox(height: 10),
            Row(
              children: [
                // Qty
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _qtyBtn(LucideIcons.minus,
                          qty > 0 ? () => _onProductMinus(product) : null),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        alignment: Alignment.center,
                        child: Text('$qty',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: qty > 0
                                    ? AppTheme.primaryColor
                                    : Colors.grey[400])),
                      ),
                      _qtyBtn(LucideIcons.plus,
                          () => _onProductPlus(product),
                          highlight: qty == 0),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Note
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showNoteDialog(cartKey, product.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasNote
                          ? AppTheme.primaryColor.withOpacity(0.08)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: hasNote
                          ? Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.3))
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            hasNote
                                ? LucideIcons.fileCheck
                                : LucideIcons.filePlus,
                            size: 14,
                            color: hasNote
                                ? AppTheme.primaryColor
                                : Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(hasNote ? 'Nota' : 'Agregar nota',
                            style: TextStyle(
                                fontSize: 12,
                                color: hasNote
                                    ? AppTheme.primaryColor
                                    : Colors.grey[500])),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap,
      {bool highlight = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: highlight ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap == null
                ? Colors.grey[300]
                : highlight
                    ? Colors.white
                    : Colors.grey[700]),
      ),
    );
  }

  // ─────────── Empty state ───────────

  Widget _emptyState() {
    return RefreshableScrollView(
      onRefresh: _refreshProducts,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.package, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No hay productos disponibles',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(
                'Este club no tiene productos disponibles en este momento',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════ EMPTY STATE ═══════════════════════
}
