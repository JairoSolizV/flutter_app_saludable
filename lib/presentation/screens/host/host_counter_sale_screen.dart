import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/entities/combo.dart';
import '../../../domain/entities/combo_cart_item.dart';
import '../../../domain/entities/product.dart';
import '../../providers/counter_sale_provider.dart';
import '../../widgets/product_image.dart';
import '../member/member_combo_detail_screen.dart';
import 'host_counter_product_configure_sheet.dart';
import 'host_counter_sale_ticket_screen.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/bolivian_price.dart';

class HostCounterSaleScreen extends StatefulWidget {
  final int clubId;
  final int hubId;

  const HostCounterSaleScreen({
    super.key,
    required this.clubId,
    required this.hubId,
  });

  @override
  State<HostCounterSaleScreen> createState() => _HostCounterSaleScreenState();
}

class _HostCounterSaleScreenState extends State<HostCounterSaleScreen> {
  String? _addingProductId;
  int? _addingComboId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CounterSaleProvider>().init(
            clubId: widget.clubId,
            hubId: widget.hubId,
          );
    });
  }

  Future<void> _handleAddProduct(
    BuildContext context,
    CounterSaleProvider provider,
    Product product,
  ) async {
    if (_addingProductId == product.id) return;

    if (!product.hasConfiguredSalePrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Precio no configurado para este producto.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _addingProductId = product.id);

    try {
      if (product.hasConfigurableOptionGroups) {
        final result = await showHostCounterProductConfigure(
          context: context,
          product: product,
        );
        if (!mounted || result == null) return;
        provider.addProductLine(
          product: result.product,
          selections: result.selections,
          quantity: result.quantity,
        );
      } else {
        provider.addProductLine(product: product);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} agregado'),
          duration: const Duration(milliseconds: 700),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _addingProductId = null);
      }
    }
  }

  Future<void> _handleAddCombo(
    BuildContext context,
    CounterSaleProvider provider,
    Combo combo,
  ) async {
    if (_addingComboId == combo.id) return;

    if (!combo.isPurchasable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Precio no configurado para este combo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _addingComboId = combo.id);

    try {
      final result = await Navigator.of(context).push<ComboCartItem>(
        MaterialPageRoute(
          builder: (_) => MemberComboDetailScreen(
            combo: combo,
            productsById: provider.productsById,
            appBarTitle: 'Configurar combo',
            addButtonLabel: 'Agregar al ticket',
            addButtonKey: const Key('host-counter-combo-add'),
          ),
        ),
      );
      if (!mounted || result == null) return;
      provider.addComboLine(result);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${combo.nombre} agregado'),
          duration: const Duration(milliseconds: 700),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _addingComboId = null);
      }
    }
  }

  void _openTicket(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HostCounterSaleTicketScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Consumer<CounterSaleProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              title: const Text('Nueva venta'),
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Menú General'),
                  Tab(text: 'Especialidades'),
                  Tab(text: 'Combos'),
                ],
              ),
            ),
            body: provider.isCatalogLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.catalogError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                provider.catalogError!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: provider.loadCatalog,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: TabBarView(
                              children: [
                                _ProductGrid(
                                  products: provider.generalProducts,
                                  crossAxisCount: 1,
                                  childAspectRatio: 3.4,
                                  isAdding: _addingProductId,
                                  bottomPadding:
                                      provider.hasCartItems ? 8 : 16,
                                  onAdd: (p) =>
                                      _handleAddProduct(context, provider, p),
                                ),
                                _ProductGrid(
                                  products: provider.clubSpecialties,
                                  crossAxisCount: 1,
                                  childAspectRatio: 3.4,
                                  isAdding: _addingProductId,
                                  bottomPadding:
                                      provider.hasCartItems ? 8 : 16,
                                  onAdd: (p) =>
                                      _handleAddProduct(context, provider, p),
                                ),
                                _ComboGrid(
                                  combos: provider.activeCombos,
                                  isAdding: _addingComboId,
                                  bottomPadding:
                                      provider.hasCartItems ? 8 : 16,
                                  onAdd: (c) =>
                                      _handleAddCombo(context, provider, c),
                                ),
                              ],
                            ),
                          ),
                          if (provider.hasCartItems)
                            _CartSummaryBar(
                              totalUnits: provider.totalCartUnits,
                              totalBs: provider.totalBs,
                              totalPuntos: provider.totalPuntos,
                              onViewTicket: () => _openTicket(context),
                            ),
                        ],
                      ),
          );
        },
      ),
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  final int totalUnits;
  final double totalBs;
  final int totalPuntos;
  final VoidCallback onViewTicket;

  const _CartSummaryBar({
    required this.totalUnits,
    required this.totalBs,
    required this.totalPuntos,
    required this.onViewTicket,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalUnits ítem${totalUnits == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      BolivianPrice.formatBs(totalBs),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Puntos: $totalPuntos',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                key: const Key('counter-view-ticket'),
                onPressed: onViewTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Ver ticket'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final void Function(Product product) onAdd;
  final int crossAxisCount;
  final double childAspectRatio;
  final double bottomPadding;
  final String? isAdding;

  const _ProductGrid({
    required this.products,
    required this.onAdd,
    required this.crossAxisCount,
    required this.childAspectRatio,
    this.bottomPadding = 12,
    this.isAdding,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(child: Text('No hay productos en esta categoría'));
    }
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        final adding = isAdding == p.id;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ProductImage(
                  imageUrl: p.imageUrl.toString().isEmpty ? null : p.imageUrl,
                  width: 52,
                  height: 52,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: adding ? null : () => onAdd(p),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          BolivianPrice.label(p.effectivePrice),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${p.puntosValor} pts',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _AddProductButton(
                  key: Key('add-product-${p.id}'),
                  loading: adding,
                  onPressed: adding ? null : () => onAdd(p),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddProductButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const _AddProductButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null
          ? AppTheme.primaryColor.withOpacity(0.5)
          : AppTheme.primaryColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: 44,
          height: 44,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _ComboGrid extends StatelessWidget {
  final List<Combo> combos;
  final void Function(Combo combo) onAdd;
  final double bottomPadding;
  final int? isAdding;

  const _ComboGrid({
    required this.combos,
    required this.onAdd,
    this.bottomPadding = 12,
    this.isAdding,
  });

  @override
  Widget build(BuildContext context) {
    if (combos.isEmpty) {
      return const Center(child: Text('No hay combos disponibles'));
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
      itemCount: combos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final combo = combos[i];
        final canBuy = combo.isPurchasable;
        final adding = isAdding == combo.id;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        combo.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        canBuy
                            ? BolivianPrice.label(combo.price)
                            : 'Precio no configurado',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: canBuy
                              ? AppTheme.primaryColor
                              : Colors.orange.shade800,
                        ),
                      ),
                      if (combo.puntosValor > 0)
                        Text(
                          '${combo.puntosValor} puntos',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      if (combo.includesCatalogSummary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Incluye:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          combo.includesCatalogSummary,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _AddProductButton(
                  key: Key('add-combo-${combo.id}'),
                  loading: adding,
                  onPressed: canBuy && !adding ? () => onAdd(combo) : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
