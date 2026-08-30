import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/entities/product.dart';
import '../../../providers/product_provider.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/input_formatters.dart';

/// Pantalla legacy. El anfitrión no debe usarla para disponibilidad ni borrado.
/// Disponibilidad: switch del listado → PATCH /clubes/{clubId}/productos/{id}/toggle.
/// Alta de LOCAL: HostProductProposalScreen.
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

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _descCtrl = TextEditingController(text: widget.product?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final product = Product(
        id: widget.product?.id ?? '0',
        name: _nameCtrl.text,
        description: _descCtrl.text,
        price: 0,
        category: 'General',
        imageUrl: '',
        active: widget.product?.active ?? true,
      );

      if (widget.product == null) {
        await Provider.of<ProductProvider>(context, listen: false)
            .createProduct(product, widget.clubId);
      } else {
        await Provider.of<ProductProvider>(context, listen: false)
            .updateProduct(product, widget.clubId);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.product == null
                  ? 'Producto creado'
                  : 'Producto actualizado')),
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Producto' : 'Nuevo Producto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                maxLength: 255,
                inputFormatters: AppFormatters.largo(255),
                decoration: const InputDecoration(
                    labelText: 'Nombre del Producto', counterText: ''),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                maxLength: 2000,
                inputFormatters: AppFormatters.largo(2000),
                decoration: const InputDecoration(
                    labelText: 'Descripción', counterText: ''),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                'La disponibilidad en tu club se gestiona desde el listado '
                '(Disponible en mi club), no desde esta pantalla.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar Producto',
                          style: TextStyle(fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
