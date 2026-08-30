import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../data/datasources/remote/product_remote_data_source.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../domain/entities/product.dart';
import '../../../widgets/product_image.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'product_option_groups_section.dart';

class HostProductProposalScreen extends StatefulWidget {
  final Product? product;

  const HostProductProposalScreen({super.key, this.product});

  @override
  State<HostProductProposalScreen> createState() =>
      _HostProductProposalScreenState();
}

class _HostProductProposalScreenState extends State<HostProductProposalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _ingredientesCtrl = TextEditingController();
  final _puntosValorCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();

  bool _isSubmitting = false;
  File? _pickedImage;
  String? _imagenUrl;
  final List<ProductOptionGroupDraft> _optionGroups = [];

  bool get _isEditing => widget.product != null;

  /// LOCAL APROBADO: edición estructural — el precio se cambia solo desde detalle.
  bool get _isStructuralEditApproved =>
      _isEditing && widget.product!.isAprobado;

  bool get _showsSalePriceField => !_isStructuralEditApproved;

  @override
  void initState() {
    super.initState();
    final existing = widget.product;
    if (existing != null) {
      _nombreCtrl.text = existing.name;
      _descripcionCtrl.text = existing.description;
      _ingredientesCtrl.text = existing.ingredientes ?? '';
      _puntosValorCtrl.text =
          existing.puntosValor > 0 ? existing.puntosValor.toString() : '';
      _precioCtrl.text = existing.price > 0
          ? existing.price.toStringAsFixed(2)
          : '';
      _imagenUrl = existing.imageUrl.isEmpty ? null : existing.imageUrl;
      final groups = existing.optionGroups;
      if (groups != null) {
        for (final group in groups) {
          _optionGroups.add(ProductOptionGroupDraft.fromGroup(group));
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() {
        _pickedImage = File(picked.path);
        _imagenUrl = null;
      });
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _ingredientesCtrl.dispose();
    _puntosValorCtrl.dispose();
    _precioCtrl.dispose();
    for (final group in _optionGroups) {
      group.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (hasUnresolvedMax(_optionGroups)) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indicá un máximo o marcá Sin límite'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final builtGroups = [
      for (var i = 0; i < _optionGroups.length; i++)
        _optionGroups[i].toGroup(orden: i),
    ];
    final groupIssues = ProductOptionGroupValidator.validate(builtGroups);
    if (groupIssues.isNotEmpty) {
      setState(() => applyOptionGroupIssues(_optionGroups, groupIssues));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(groupIssues.first.message),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => applyOptionGroupIssues(_optionGroups, const []));

    final puntos = int.tryParse(_puntosValorCtrl.text.trim());
    if (puntos == null || puntos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un valor de puntos válido (entero positivo).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    late final double precio;
    if (_isStructuralEditApproved) {
      precio = widget.product!.price;
    } else {
      final parsed = _parsePrecio(_precioCtrl.text);
      if (parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingresa un precio mayor a 0'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      precio = parsed;
    }

    setState(() => _isSubmitting = true);

    try {
      final dataSource =
          Provider.of<ProductRemoteDataSource>(context, listen: false);
      final clubDataSource = _isEditing
          ? null
          : Provider.of<ClubRemoteDataSource>(context, listen: false);

      String? imagenUrlToSend = _imagenUrl;
      if (_pickedImage != null) {
        imagenUrlToSend = await dataSource.uploadProductImage(_pickedImage!);
      }

      if (_isEditing) {
        final original = widget.product!;
        final updated = original.copyWith(
          name: _nombreCtrl.text.trim(),
          description: _descripcionCtrl.text.trim(),
          ingredientes: _ingredientesCtrl.text.trim(),
          puntosValor: puntos,
          price: _isStructuralEditApproved ? original.price : precio,
          effectivePrice: _isStructuralEditApproved
              ? original.effectivePrice
              : (original.clubSalePrice ?? precio),
          imageUrl: (imagenUrlToSend != null && imagenUrlToSend.isNotEmpty)
              ? imagenUrlToSend
              : original.imageUrl,
          optionGroups: builtGroups,
        );
        final saved = await dataSource.updateProduct(updated);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(saved);
        return;
      }

      final club = await clubDataSource!.getMyClub();

      if (club == null) {
        throw Exception(
            'No se encontró tu club. Verifica que tengas un club asignado como anfitrión.');
      }

      await dataSource.createProductProposal(
        hubId: club.hubId,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        ingredientes: _ingredientesCtrl.text.trim(),
        puntosValor: puntos,
        precio: precio,
        imagenUrl: imagenUrlToSend,
        optionGroups: builtGroups.isEmpty ? null : builtGroups,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Propuesta enviada'),
          content: const Text(
            'Producto enviado a revisión. Una vez el Administrador lo apruebe, '
            'podrás hacerlo visible para tus socios.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Error al guardar: ${ErrorMapper.publicMessage(e)}'
                : 'Error al enviar la propuesta: ${ErrorMapper.publicMessage(e)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  static double? _parsePrecio(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isEditing ? 'Editar propuesta' : 'Proponer Producto del Club'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Completa los datos del batido/producto que quieres que el Administrador revise '
                'para tu menú propio.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text('Foto del producto',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _isSubmitting ? null : _pickImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: _pickedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child:
                                  Image.file(_pickedImage!, fit: BoxFit.cover),
                            )
                          : _imagenUrl != null && _imagenUrl!.isNotEmpty
                              ? ProductImage(
                                  imageUrl: _imagenUrl, width: 100, height: 100)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.imagePlus,
                                        size: 32, color: Colors.grey[600]),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Elegir de galería',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600]),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'O pega la URL de la imagen',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() =>
                          _imagenUrl = v.trim().isEmpty ? null : v.trim()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Producto',
                  prefixIcon: Icon(LucideIcons.coffee),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El nombre es obligatorio'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ingredientesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ingredientes (obligatorio)',
                  hintText: 'Ej: Té verde, aloe, proteína, hielo...',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(LucideIcons.list),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Debes detallar los ingredientes para que el Admin pueda revisarlo'
                    : null,
              ),
              if (_showsSalePriceField) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('precio-venta-field'),
                  controller: _precioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio de venta (Bs)',
                    hintText: 'Ej: 32.00',
                    helperText:
                        'Precio en bolivianos. Los puntos son fidelización, no precio.',
                    prefixIcon: Icon(LucideIcons.banknote),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final n = _parsePrecio(v ?? '');
                    if (n == null) return 'Ingresa un precio válido';
                    if (n <= 0) return 'Ingresa un precio mayor a 0';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _puntosValorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Puntos de fidelización',
                  hintText: 'Ej: 10',
                  helperText: 'No es el precio de venta.',
                  prefixIcon: Icon(LucideIcons.star),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa los puntos de valor'
                    : null,
              ),
              const SizedBox(height: 16),
              if (_isEditing && widget.product!.isAprobado) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text(
                    'Al guardar cambios en la definición, el producto volverá a revisión.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ProductOptionGroupsSection(
                groups: _optionGroups,
                enabled: !_isSubmitting,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          _isEditing ? LucideIcons.pencil : LucideIcons.send),
                  label: Text(
                    _isSubmitting
                        ? (_isEditing ? 'Guardando...' : 'Enviando...')
                        : (_isEditing
                            ? 'Guardar cambios'
                            : 'Enviar a Revisión'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
