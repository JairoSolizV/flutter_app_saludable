import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/entities/product.dart';
import '../../../providers/product_provider.dart';

class HostEditProductScreen extends StatefulWidget {
  final int clubId;
  final Product? product; // Optional for edit mode

  const HostEditProductScreen({super.key, required this.clubId, this.product});

  @override
  State<HostEditProductScreen> createState() => _HostEditProductScreenState();
}

class _HostEditProductScreenState extends State<HostEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _catCtrl;
  late TextEditingController _imgCtrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _descCtrl = TextEditingController(text: widget.product?.description ?? '');
    _priceCtrl = TextEditingController(text: widget.product?.price.toString() ?? '');
    
    // Validar que la categoría exista en la lista, si no, usar 'General'
    final validCategories = ['Batidos', 'Tés', 'Aloes', 'Barras', 'Otros', 'General'];
    final initialCat = widget.product?.category ?? 'Batidos';
    _catCtrl = TextEditingController(text: validCategories.contains(initialCat) ? initialCat : 'General');
    
    _imgCtrl = TextEditingController(text: widget.product?.imageUrl ?? '');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final product = Product(
        id: widget.product?.id ?? '0',
        name: _nameCtrl.text,
        description: _descCtrl.text,
        price: double.parse(_priceCtrl.text),
        category: _catCtrl.text,
        imageUrl: _imgCtrl.text,
      );

      if (widget.product == null) {
        // Create
        await Provider.of<ProductProvider>(context, listen: false).createProduct(product, widget.clubId);
      } else {
        // Update
        await Provider.of<ProductProvider>(context, listen: false).updateProduct(product, widget.clubId);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.product == null ? 'Producto creado' : 'Producto actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: const Text('¿Estás seguro de que quieres eliminar este producto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await Provider.of<ProductProvider>(context, listen: false).deleteProduct(widget.product!.id, widget.clubId);
      if (mounted) {
        context.pop();
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto eliminado')));
      }
    } catch(e) {
      if (mounted) {
         setState(() => _isSaving = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Producto' : 'Nuevo Producto'),
        actions: isEdit ? [
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _isSaving ? null : _delete)
        ] : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del Producto'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Precio (Bs.)', prefixText: 'Bs. '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v) == null) return 'Inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _catCtrl.text,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: ['Batidos', 'Tés', 'Aloes', 'Barras', 'Otros', 'General']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _catCtrl.text = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imgCtrl,
                decoration: const InputDecoration(
                    labelText: 'URL de Imagen (Opcional)',
                    hintText: 'https://ejemplo.com/foto.jpg'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7AC142)),
                  child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar Producto', style: TextStyle(fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
