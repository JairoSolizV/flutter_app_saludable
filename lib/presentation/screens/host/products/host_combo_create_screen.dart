import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/entities/combo.dart';
import '../../../../domain/entities/sabor.dart';
import '../../../../data/datasources/remote/combo_remote_data_source.dart';
import '../../../../data/datasources/remote/product_remote_data_source.dart';
import '../../../../data/datasources/remote/sabor_remote_data_source.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import '../../../widgets/product_image.dart';

/// Pantalla para crear o editar un combo personalizado del club.
class HostComboCreateScreen extends StatefulWidget {
  final int clubId;
  final Combo? existingCombo;

  const HostComboCreateScreen({
    super.key,
    required this.clubId,
    this.existingCombo,
  });

  @override
  State<HostComboCreateScreen> createState() => _HostComboCreateScreenState();
}

class _ComboItemDraft {
  Product product;
  Sabor? sabor;
  int cantidad;

  _ComboItemDraft({required this.product, this.sabor, this.cantidad = 1});

  int get puntos => (product.puntosValor) * cantidad;
}

class _HostComboCreateScreenState extends State<HostComboCreateScreen> {
  static const int _maxItems = 3;

  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();

  List<Product> _availableProducts = [];
  bool _isLoadingProducts = true;
  bool _isSaving = false;

  final List<_ComboItemDraft> _items = [];

  bool get _isEditing => widget.existingCombo != null;

  int get _totalPuntos => _items.fold(0, (sum, item) => sum + item.puntos);

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nombreController.text = widget.existingCombo!.nombre;
      _descripcionController.text = widget.existingCombo!.descripcion ?? '';
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final productDs = Provider.of<ProductRemoteDataSource>(context, listen: false);
      final products = await productDs.getAvailableProductsByClub(widget.clubId);
      if (mounted) {
        setState(() {
          _availableProducts = products;
          _isLoadingProducts = false;
        });
        // If editing, populate items from existing combo
        if (_isEditing) {
          _populateExistingItems();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoadingProducts = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando productos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _populateExistingItems() {
    for (final comboItem in widget.existingCombo!.items) {
      final product = _availableProducts.where((p) => p.id == comboItem.productoId.toString()).firstOrNull;
      if (product != null) {
        _items.add(_ComboItemDraft(
          product: product,
          sabor: comboItem.saborId != null
              ? Sabor(id: comboItem.saborId!, nombre: comboItem.saborNombre ?? '', disponible: true)
              : null,
          cantidad: comboItem.cantidad,
        ));
      }
    }
    setState(() {});
  }

  void _addProduct() async {
    if (_items.length >= _maxItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Máximo $_maxItems productos por combo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar selector de producto
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ProductSelectorSheet(
        products: _availableProducts,
        alreadySelected: _items.map((i) => i.product.id).toList(),
      ),
    );

    if (selected == null || !mounted) return;

    // Intentar cargar sabores del producto
    Sabor? selectedSabor;
    try {
      final saborDs = Provider.of<SaborRemoteDataSource>(context, listen: false);
      final sabores = await saborDs.getSaboresDeProductoEnClub(widget.clubId, int.parse(selected.id));
      final disponibles = sabores.where((s) => s.disponible).toList();

      if (disponibles.isNotEmpty && mounted) {
        selectedSabor = await showModalBottomSheet<Sabor>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) => _SaborSelectorSheet(sabores: disponibles, productoNombre: selected.name),
        );
        // If user cancelled sabor selection, still add without sabor
      }
    } catch (_) {
      // No sabores or error — continue without
    }

    if (mounted) {
      setState(() {
        _items.add(_ComboItemDraft(product: selected, sabor: selectedSabor));
      });
    }
  }

  void _removeItem(int index) {
    setState(() { _items.removeAt(index); });
  }

  void _changeCantidad(int index, int delta) {
    final item = _items[index];
    final newCantidad = item.cantidad + delta;
    if (newCantidad >= 1 && newCantidad <= 5) {
      setState(() { item.cantidad = newCantidad; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto al combo'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() { _isSaving = true; });

    try {
      final comboDs = Provider.of<ComboRemoteDataSource>(context, listen: false);
      final itemsPayload = _items.map((item) => <String, dynamic>{
        'productoId': int.parse(item.product.id),
        if (item.sabor != null) 'saborId': item.sabor!.id,
        'cantidad': item.cantidad,
      }).toList();

      if (_isEditing) {
        await comboDs.updateCombo(
          widget.clubId,
          widget.existingCombo!.id!,
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim().isEmpty ? null : _descripcionController.text.trim(),
          items: itemsPayload,
        );
      } else {
        await comboDs.createCombo(
          widget.clubId,
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim().isEmpty ? null : _descripcionController.text.trim(),
          items: itemsPayload,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Combo actualizado' : 'Combo creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSaving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Combo' : 'Nuevo Combo'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoadingProducts
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Nombre
                  TextFormField(
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: 'Nombre del combo *',
                      hintText: 'Ej: Combo Energía',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
                  ),
                  const SizedBox(height: 16),

                  // Descripción
                  TextFormField(
                    controller: _descripcionController,
                    decoration: InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText: 'Ej: Ideal para después del ejercicio',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // Productos del combo header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Productos (${_items.length}/$_maxItems)',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_items.length < _maxItems)
                        TextButton.icon(
                          onPressed: _addProduct,
                          icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                          label: const Text('Agregar', style: TextStyle(color: AppTheme.primaryColor)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Items list
                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.add_shopping_cart, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Agrega productos al combo',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _addProduct,
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar Producto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Product image
                              ProductImage(
                                imageUrl: item.product.imageUrl.isEmpty ? null : item.product.imageUrl,
                                width: 50,
                                height: 50,
                              ),
                              const SizedBox(width: 12),
                              // Product info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (item.sabor != null)
                                      Text(
                                        'Sabor: ${item.sabor!.nombre}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    Text(
                                      '${item.product.puntosValor} pts c/u',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                                    ),
                                  ],
                                ),
                              ),
                              // Cantidad controls
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    onPressed: item.cantidad > 1 ? () => _changeCantidad(index, -1) : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                  Text(
                                    '${item.cantidad}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: item.cantidad < 5 ? () => _changeCantidad(index, 1) : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                ],
                              ),
                              // Delete
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Resumen de puntos
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Puntos del Combo:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$_totalPuntos pts',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Botón guardar
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isEditing ? 'Actualizar Combo' : 'Crear Combo',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

// ===================== Product Selector Bottom Sheet =====================

class _ProductSelectorSheet extends StatefulWidget {
  final List<Product> products;
  final List<String> alreadySelected;

  const _ProductSelectorSheet({required this.products, required this.alreadySelected});

  @override
  State<_ProductSelectorSheet> createState() => _ProductSelectorSheetState();
}

class _ProductSelectorSheetState extends State<_ProductSelectorSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) {
      if (_search.isNotEmpty && !p.name.toLowerCase().contains(_search.toLowerCase())) return false;
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Seleccionar Producto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No hay productos disponibles', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final alreadyAdded = widget.alreadySelected.contains(product.id);
                        return ListTile(
                          leading: ProductImage(
                            imageUrl: product.imageUrl.isEmpty ? null : product.imageUrl,
                            width: 40,
                            height: 40,
                          ),
                          title: Text(product.name),
                          subtitle: Text('${product.puntosValor} pts  •  ${product.tipo}'),
                          trailing: alreadyAdded
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                          enabled: !alreadyAdded,
                          onTap: alreadyAdded ? null : () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ===================== Sabor Selector Bottom Sheet =====================

class _SaborSelectorSheet extends StatelessWidget {
  final List<Sabor> sabores;
  final String productoNombre;

  const _SaborSelectorSheet({required this.sabores, required this.productoNombre});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Sabor para $productoNombre',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // Opción sin sabor
          ListTile(
            leading: const Icon(Icons.no_food, color: Colors.grey),
            title: const Text('Sin sabor específico'),
            onTap: () => Navigator.pop(context, null),
          ),
          const Divider(),
          ...sabores.map((sabor) => ListTile(
            leading: const Icon(Icons.icecream, color: AppTheme.primaryColor),
            title: Text(sabor.nombre),
            onTap: () => Navigator.pop(context, sabor),
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
