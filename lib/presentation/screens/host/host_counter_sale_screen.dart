import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../data/datasources/remote/order_remote_data_source.dart';
import '../../../data/datasources/remote/product_remote_data_source.dart';
import '../../../data/datasources/remote/combo_remote_data_source.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/combo.dart';
import '../../providers/counter_sale_provider.dart';
import '../../widgets/product_image.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

class HostCounterSaleScreen extends StatelessWidget {
  final int clubId;
  final int hubId;

  const HostCounterSaleScreen({
    super.key,
    required this.clubId,
    required this.hubId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CounterSaleProvider(
        Provider.of<ProductRemoteDataSource>(context, listen: false),
        Provider.of<OrderRemoteDataSource>(context, listen: false),
        Provider.of<ComboRemoteDataSource>(context, listen: false),
      )..init(clubId: clubId, hubId: hubId),
      child: const _HostCounterSaleView(),
    );
  }
}

class _HostCounterSaleView extends StatefulWidget {
  const _HostCounterSaleView();

  @override
  State<_HostCounterSaleView> createState() => _HostCounterSaleViewState();
}

class _HostCounterSaleViewState extends State<_HostCounterSaleView> {
  final TextEditingController _socioCtrl = TextEditingController();
  final TextEditingController _obsCtrl = TextEditingController();
  bool _showMobileTicket = false;

  @override
  void dispose() {
    _socioCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _finalizarVenta(BuildContext context) async {
    try {
      final provider = Provider.of<CounterSaleProvider>(context, listen: false);
      final ok = await provider.submitCounterSale();
      if (!mounted) return;

      if (ok) {
        final action = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: const Text('Venta registrada'),
                content: const Text('Venta registrada correctamente'),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop('nueva_venta'),
                    child: const Text('Nueva venta'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop('ver_pedidos'),
                    child: const Text('Ver pedidos'),
                  ),
                ],
              ),
        );

        if (!mounted) return;

        if (action == 'nueva_venta') {
          provider.resetSale();
          _socioCtrl.clear();
          _obsCtrl.clear();
        } else if (action == 'ver_pedidos') {
          Navigator.of(context).pop(true);
        }
      } else {
        final message = provider.submitError ?? 'No se pudo registrar la venta';
        final isMaxSabores = message.contains('MAX_SABORES_EXCEDIDO') || message.contains('3 sabores');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMaxSabores
                ? 'Máximo ${CounterSaleProvider.maxSabores} sabores por combo. Reduce los productos.'
                : message),
            backgroundColor: isMaxSabores ? Colors.orange : Colors.red,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[COUNTER SALE UI] finalizar error: $e');
      debugPrint('[COUNTER SALE UI] stack: $st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error inesperado al finalizar la venta.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleMobileTicket() {
    setState(() {
      _showMobileTicket = !_showMobileTicket;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Consumer<CounterSaleProvider>(
        builder: (context, provider, _) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 900;
          return Scaffold(
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
            bottomNavigationBar: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${provider.totalItems} item(s)',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Total puntos: ${provider.totalPuntos}',
                            style: const TextStyle(color: AppTheme.primaryColor),
                          ),
                          Row(
                            children: [
                              const Text('Sabores: ', style: TextStyle(fontSize: 12)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: provider.isMaxSaboresReached ? Colors.orange.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: provider.isMaxSaboresReached ? Colors.orange : Colors.green,
                                  ),
                                ),
                                child: Text(
                                  '${provider.distinctProducts}/${CounterSaleProvider.maxSabores}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: provider.isMaxSaboresReached ? Colors.orange.shade800 : Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isMobile) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _toggleMobileTicket,
                          icon: const Icon(LucideIcons.receipt),
                          label: Text(
                            _showMobileTicket
                                ? 'Ocultar ticket'
                                : 'Ticket (${provider.totalItems})',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: provider.canSubmit
                            ? () => _finalizarVenta(context)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: provider.isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.checkCircle2),
                        label: Text(provider.isSubmitting
                            ? 'Registrando...'
                            : 'Finalizar venta'),
                      ),
                    ),
                  ],
                ),
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
                              Text(provider.catalogError!,
                                  textAlign: TextAlign.center),
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
                          _buildClienteBlock(provider, isMobile: isMobile),
                          Expanded(
                            child: isMobile
                                ? Column(
                                    children: [
                                      Expanded(
                                        child: TabBarView(
                                          children: [
                                            _ProductGrid(
                                              products: provider.generalProducts,
                                              crossAxisCount: 1,
                                              childAspectRatio: 3.2,
                                              onAdd: (p) {
                                                final added = provider.addProduct(p);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(added
                                                        ? '${p.name} agregado al ticket'
                                                        : 'Máximo ${CounterSaleProvider.maxSabores} sabores por combo.'),
                                                    backgroundColor: added ? null : Colors.orange,
                                                    duration: Duration(milliseconds: added ? 700 : 2500),
                                                  ),
                                                );
                                              },
                                            ),
                                            _ProductGrid(
                                              products:
                                                  provider.clubSpecialties,
                                              crossAxisCount: 1,
                                              childAspectRatio: 3.2,
                                              onAdd: (p) {
                                                final added = provider.addProduct(p);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(added
                                                        ? '${p.name} agregado al ticket'
                                                        : 'Máximo ${CounterSaleProvider.maxSabores} sabores por combo.'),
                                                    backgroundColor: added ? null : Colors.orange,
                                                    duration: Duration(milliseconds: added ? 700 : 2500),
                                                  ),
                                                );
                                              },
                                            ),
                                            _ComboGrid(
                                              combos: provider.activeCombos,
                                              crossAxisCount: 1,
                                              onAdd: (combo) {
                                                final added = provider.addCombo(combo);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(added
                                                        ? 'Combo "${combo.nombre}" agregado al ticket'
                                                        : 'No hay espacio para agregar este combo (máx. ${CounterSaleProvider.maxSabores} sabores).'),
                                                    backgroundColor: added ? Colors.green : Colors.orange,
                                                    duration: Duration(milliseconds: added ? 1200 : 2500),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_showMobileTicket)
                                        SizedBox(
                                          height:
                                              MediaQuery.of(context).size.height *
                                                  0.42,
                                          child: _TicketPanel(
                                            obsCtrl: _obsCtrl,
                                            showLeftBorder: false,
                                          ),
                                        ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: TabBarView(
                                          children: [
                                            _ProductGrid(
                                              products: provider.generalProducts,
                                              crossAxisCount: 2,
                                              childAspectRatio: 1.8,
                                              onAdd: (p) {
                                                final added = provider.addProduct(p);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(added
                                                        ? '${p.name} agregado al ticket'
                                                        : 'Máximo ${CounterSaleProvider.maxSabores} sabores por combo.'),
                                                    backgroundColor: added ? null : Colors.orange,
                                                    duration: Duration(milliseconds: added ? 700 : 2500),
                                                  ),
                                                );
                                              },
                                            ),
                                            _ProductGrid(
                                              products:
                                                  provider.clubSpecialties,
                                              crossAxisCount: 2,
                                              childAspectRatio: 1.8,
                                              onAdd: (p) {
                                                final added = provider.addProduct(p);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(added
                                                        ? '${p.name} agregado al ticket'
                                                        : 'Máximo ${CounterSaleProvider.maxSabores} sabores por combo.'),
                                                    backgroundColor: added ? null : Colors.orange,
                                                    duration: Duration(milliseconds: added ? 700 : 2500),
                                                  ),
                                                );
                                              },
                                            ),
                                            _ComboGrid(
                                              combos: provider.activeCombos,
                                              crossAxisCount: 2,
                                              onAdd: (combo) {
                                                final added = provider.addCombo(combo);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(added
                                                        ? 'Combo "${combo.nombre}" agregado al ticket'
                                                        : 'No hay espacio para agregar este combo (máx. ${CounterSaleProvider.maxSabores} sabores).'),
                                                    backgroundColor: added ? Colors.green : Colors.orange,
                                                    duration: Duration(milliseconds: added ? 1200 : 2500),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: _TicketPanel(
                                          obsCtrl: _obsCtrl,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
          );
        },
      ),
    );
  }

  Widget _buildClienteBlock(CounterSaleProvider provider, {required bool isMobile}) {
    final isPublic = provider.socioCodigo.trim().isEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _socioCtrl,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Código de socio',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: provider.setSocioCodigo,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  provider.setSocioCodigo(_socioCtrl.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Código capturado. La validación real ocurre al finalizar venta.',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Validar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(isPublic ? 'Venta al público' : 'Código capturado'),
              backgroundColor: isPublic
                  ? Colors.grey.shade100
                  : AppTheme.primaryColor.withOpacity(0.15),
            ),
          ),
          if (isMobile)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tip: abre Ticket para editar cantidades y notas.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final void Function(Product product) onAdd;
  final int crossAxisCount;
  final double childAspectRatio;

  const _ProductGrid({
    required this.products,
    required this.onAdd,
    required this.crossAxisCount,
    required this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(child: Text('No hay productos en esta categoría'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        return InkWell(
          onTap: () => onAdd(p),
          borderRadius: BorderRadius.circular(12),
          child: Card(
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
                          '${p.puntosValor} pts',
                          style: const TextStyle(color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.plusCircle, color: AppTheme.primaryColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ComboGrid extends StatelessWidget {
  final List<Combo> combos;
  final void Function(Combo combo) onAdd;
  final int crossAxisCount;

  const _ComboGrid({
    required this.combos,
    required this.onAdd,
    required this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    if (combos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fastfood_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No hay combos disponibles', style: TextStyle(color: Colors.grey)),
            Text('Crea combos desde Mi Menú', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: combos.length,
      itemBuilder: (context, i) {
        final combo = combos[i];
        final itemsText = combo.items.map((item) {
          String label = '${item.cantidad}x ${item.productoNombre}';
          if (item.saborNombre != null) label += ' (${item.saborNombre})';
          return label;
        }).join(' + ');

        return InkWell(
          onTap: () => onAdd(combo),
          borderRadius: BorderRadius.circular(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: const Icon(Icons.fastfood, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          combo.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          itemsText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${combo.puntosValor} pts',
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.plusCircle, color: AppTheme.primaryColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TicketPanel extends StatelessWidget {
  final TextEditingController obsCtrl;
  final bool showLeftBorder;

  const _TicketPanel({
    required this.obsCtrl,
    this.showLeftBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CounterSaleProvider>(
      builder: (context, provider, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: showLeftBorder
                ? Border(left: BorderSide(color: Colors.grey.shade300))
                : null,
          ),
          child: Column(
            children: [
              const ListTile(
                title: Text('Ticket', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: provider.cartItems.isEmpty
                    ? const Center(child: Text('Sin productos agregados'))
                    : ListView.builder(
                        itemCount: provider.cartItems.length,
                        itemBuilder: (context, i) {
                          final item = provider.cartItems[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.comboNombre != null)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Combo: ${item.comboNombre}',
                                        style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.product.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => provider
                                            .removeItem(item.product.id),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      _QtyButton(
                                        icon: Icons.remove,
                                        onTap: () => provider
                                            .decreaseQty(item.product.id),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      _QtyButton(
                                        icon: Icons.add,
                                        onTap: () => provider
                                            .increaseQty(item.product.id),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    initialValue: item.note,
                                    onChanged: (v) =>
                                        provider.setItemNote(item.product.id, v),
                                    decoration: const InputDecoration(
                                      hintText: 'Nota del ítem (opcional)',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: obsCtrl,
                  onChanged: provider.setObservaciones,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
