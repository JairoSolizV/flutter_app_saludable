import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../data/datasources/remote/order_remote_data_source.dart';
import '../../../data/datasources/remote/product_remote_data_source.dart';
import '../../../domain/entities/product.dart';
import '../../providers/counter_sale_provider.dart';
import '../../widgets/product_image.dart';

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

  @override
  void dispose() {
    _socioCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _finalizarVenta(BuildContext context) async {
    final provider = Provider.of<CounterSaleProvider>(context, listen: false);
    final ok = await provider.submitCounterSale();
    if (!mounted) return;

    if (ok) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Venta registrada'),
          content: const Text('Venta registrada correctamente'),
          actions: [
            TextButton(
              onPressed: () {
                provider.resetSale();
                _socioCtrl.clear();
                _obsCtrl.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Nueva venta'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text('Ver pedidos'),
            ),
          ],
        ),
      );
    } else {
      final message = provider.submitError ?? 'No se pudo registrar la venta';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openTicketSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final height = MediaQuery.of(context).size.height * 0.85;
        return SafeArea(
          child: SizedBox(
            height: height,
            child: _TicketPanel(obsCtrl: _obsCtrl, showLeftBorder: false),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Consumer<CounterSaleProvider>(
        builder: (context, provider, _) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 900;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Nueva venta'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Menú General'),
                  Tab(text: 'Especialidades del Club'),
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
                            style: const TextStyle(color: Color(0xFF7AC142)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isMobile) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openTicketSheet(context),
                          icon: const Icon(LucideIcons.receipt),
                          label: Text('Ticket (${provider.totalItems})'),
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
                          backgroundColor: const Color(0xFF7AC142),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TabBarView(
                                    children: [
                                      _ProductGrid(
                                        products: provider.generalProducts,
                                        crossAxisCount: isMobile ? 1 : 2,
                                        childAspectRatio: isMobile ? 3.2 : 1.8,
                                        onAdd: (p) {
                                          provider.addProduct(p);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '${p.name} agregado al ticket'),
                                              duration:
                                                  const Duration(milliseconds: 700),
                                            ),
                                          );
                                        },
                                      ),
                                      _ProductGrid(
                                        products: provider.clubSpecialties,
                                        crossAxisCount: isMobile ? 1 : 2,
                                        childAspectRatio: isMobile ? 3.2 : 1.8,
                                        onAdd: (p) {
                                          provider.addProduct(p);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '${p.name} agregado al ticket'),
                                              duration:
                                                  const Duration(milliseconds: 700),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isMobile)
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
                  : const Color(0xFF7AC142).withOpacity(0.15),
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
                          style: const TextStyle(color: Color(0xFF7AC142)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.plusCircle, color: Color(0xFF7AC142)),
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
          backgroundColor: const Color(0xFF7AC142),
          foregroundColor: Colors.white,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
