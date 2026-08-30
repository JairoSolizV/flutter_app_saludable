import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/entities/combo.dart';
import '../../../../data/datasources/remote/combo_remote_data_source.dart';
import '../../../../data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/bolivian_price.dart';
import 'package:flutter_app_saludable/core/utils/input_formatters.dart';
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
  int cantidad;

  _ComboItemDraft({required this.product, this.cantidad = 1});

  int get puntos => product.puntosValor * cantidad;
}

class _HostComboCreateScreenState extends State<HostComboCreateScreen> {
  static const int _maxItems = 3;

  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();

  List<Product> _availableProducts = [];
  bool _isLoadingProducts = true;
  bool _isSaving = false;

  final List<_ComboItemDraft> _items = [];

  bool get _isEditing => widget.existingCombo != null;

  int get _totalPuntos => _items.fold(0, (sum, item) => sum + item.puntos);

  double get _referenceSeparateTotal => Combo.referenceSeparateTotal(
        _items.map(
          (i) => ComboItem(
            productoId: int.parse(i.product.id),
            productoNombre: i.product.name,
            cantidad: i.cantidad,
          ),
        ),
        (productoId) {
          final product = _availableProducts
              .where((p) => p.id == productoId.toString())
              .firstOrNull;
          return product?.effectivePrice ?? 0;
        },
      );

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final combo = widget.existingCombo!;
      _nombreController.text = combo.nombre;
      _descripcionController.text = combo.descripcion ?? '';
      if (combo.price > 0) {
        _precioController.text = combo.price.toStringAsFixed(2);
      }
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final productDs =
          Provider.of<ProductRemoteDataSource>(context, listen: false);
      final products =
          await productDs.getAvailableProductsByClub(widget.clubId);
      if (mounted) {
        setState(() {
          _availableProducts = products;
          _isLoadingProducts = false;
        });
        if (_isEditing) {
          _populateExistingItems();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando productos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _populateExistingItems() {
    for (final comboItem in widget.existingCombo!.items) {
      final product = _availableProducts
          .where((p) => p.id == comboItem.productoId.toString())
          .firstOrNull;
      if (product != null) {
        _items.add(_ComboItemDraft(
          product: product,
          cantidad: comboItem.cantidad,
        ));
      }
    }
    setState(() {});
  }

  Future<void> _addProduct() async {
    if (_items.length >= _maxItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Máximo $_maxItems productos por combo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

    setState(() {
      _items.add(_ComboItemDraft(product: selected));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _changeCantidad(int index, int delta) {
    final item = _items[index];
    final newCantidad = item.cantidad + delta;
    if (newCantidad >= 1 && newCantidad <= 5) {
      setState(() {
        item.cantidad = newCantidad;
      });
    }
  }

  double? _parsePrecioInput() {
    final raw = _precioController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String? _validatePrecio(String? _) {
    final value = _parsePrecioInput();
    if (value == null || value <= 0) {
      return 'Ingresa un precio mayor a 0';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un producto al combo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final precio = _parsePrecioInput();
    if (precio == null || precio <= 0) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final comboDs =
          Provider.of<ComboRemoteDataSource>(context, listen: false);
      final itemsPayload = _items
          .map((item) => <String, dynamic>{
                'productoId': int.parse(item.product.id),
                'cantidad': item.cantidad,
              })
          .toList();

      if (_isEditing) {
        await comboDs.updateCombo(
          widget.clubId,
          widget.existingCombo!.id!,
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim().isEmpty
              ? null
              : _descripcionController.text.trim(),
          precio: precio,
          items: itemsPayload,
        );
      } else {
        await comboDs.createCombo(
          widget.clubId,
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim().isEmpty
              ? null
              : _descripcionController.text.trim(),
          precio: precio,
          items: itemsPayload,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Combo actualizado' : 'Combo creado exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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
                  TextFormField(
                    controller: _nombreController,
                    maxLength: 150,
                    inputFormatters: AppFormatters.largo(150),
                    decoration: InputDecoration(
                      labelText: 'Nombre del combo *',
                      hintText: 'Ej: Combo Energía',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      counterText: '',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'El nombre es requerido'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descripcionController,
                    maxLength: 2000,
                    inputFormatters: AppFormatters.largo(2000),
                    decoration: InputDecoration(
                      labelText: 'Descripción (opcional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      counterText: '',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Productos (${_items.length}/$_maxItems)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_items.length < _maxItems)
                        TextButton.icon(
                          onPressed: _addProduct,
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: AppTheme.primaryColor,
                          ),
                          label: const Text(
                            'Agregar',
                            style: TextStyle(color: AppTheme.primaryColor),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.add_shopping_cart,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Agrega productos al combo',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ProductImage(
                                imageUrl: item.product.imageUrl.isEmpty
                                    ? null
                                    : item.product.imageUrl,
                                width: 50,
                                height: 50,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      BolivianPrice.label(
                                        item.product.effectivePrice,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      size: 20,
                                    ),
                                    onPressed: item.cantidad > 1
                                        ? () => _changeCantidad(index, -1)
                                        : null,
                                  ),
                                  Text('${item.cantidad}'),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: 20,
                                    ),
                                    onPressed: item.cantidad < 5
                                        ? () => _changeCantidad(index, 1)
                                        : null,
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total por separado',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          key: const Key('host-combo-reference-total'),
                          BolivianPrice.formatBs(_referenceSeparateTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('host-combo-price-field'),
                    controller: _precioController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: AppFormatters.decimal(enteros: 5),
                    decoration: InputDecoration(
                      labelText: 'Precio de venta del combo (Bs) *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: _validatePrecio,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Puntos del combo: $_totalPuntos',
                    key: const Key('host-combo-points-preview'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing ? 'Actualizar Combo' : 'Crear Combo',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProductSelectorSheet extends StatefulWidget {
  final List<Product> products;
  final List<String> alreadySelected;

  const _ProductSelectorSheet({
    required this.products,
    required this.alreadySelected,
  });

  @override
  State<_ProductSelectorSheet> createState() => _ProductSelectorSheetState();
}

class _ProductSelectorSheetState extends State<_ProductSelectorSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) {
      if (_search.isNotEmpty &&
          !p.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Seleccionar Producto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                maxLength: 100,
                inputFormatters: AppFormatters.largo(100),
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  isDense: true,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  final alreadyAdded =
                      widget.alreadySelected.contains(product.id);
                  return ListTile(
                    leading: ProductImage(
                      imageUrl:
                          product.imageUrl.isEmpty ? null : product.imageUrl,
                      width: 40,
                      height: 40,
                    ),
                    title: Text(product.name),
                    subtitle: Text(
                      '${BolivianPrice.label(product.effectivePrice)} · ${product.puntosValor} pts',
                    ),
                    trailing: alreadyAdded
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(
                            Icons.add_circle_outline,
                            color: AppTheme.primaryColor,
                          ),
                    enabled: !alreadyAdded,
                    onTap:
                        alreadyAdded ? null : () => Navigator.pop(context, product),
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
