import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/presentation/widgets/product_image.dart';

class HostProductReviewScreen extends StatefulWidget {
  final Product product;
  final int clubId;

  const HostProductReviewScreen({
    super.key,
    required this.product,
    required this.clubId,
  });

  @override
  State<HostProductReviewScreen> createState() =>
      _HostProductReviewScreenState();
}

class _HostProductReviewScreenState extends State<HostProductReviewScreen> {
  late Product _product;
  bool _didChange = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  void _popWithResult() {
    Navigator.of(context).pop(_didChange);
  }

  Future<void> _editProposal() async {
    final result = await context.push<Object?>(
      '/host/products/proposal',
      extra: _product,
    );
    if (!mounted) return;
    if (result is Product) {
      setState(() {
        _product = result;
        _didChange = true;
      });
    } else if (result == true) {
      setState(() => _didChange = true);
    }
  }

  Future<void> _confirmResend() async {
    if (_isResending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reenviar producto?'),
        content: const Text(
          'El producto volverá a estado Pendiente para que el administrador revise los cambios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reenviar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _resend();
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      final ds = Provider.of<ProductRemoteDataSource>(context, listen: false);
      final updated = await ds.reenviarProducto(_product.id);
      if (!mounted) return;
      setState(() {
        _product = _product.copyWith(
          estadoAprobacion: 'PENDIENTE',
          name: updated.name.isNotEmpty ? updated.name : _product.name,
          description: updated.description.isNotEmpty
              ? updated.description
              : _product.description,
          ingredientes: updated.ingredientes ?? _product.ingredientes,
          puntosValor: updated.puntosValor > 0
              ? updated.puntosValor
              : _product.puntosValor,
          imageUrl: updated.imageUrl.isNotEmpty
              ? updated.imageUrl
              : _product.imageUrl,
          comentarioRevision:
              updated.comentarioRevision ?? _product.comentarioRevision,
          revisadoPorNombre:
              updated.revisadoPorNombre ?? _product.revisadoPorNombre,
          revisadoAt: updated.revisadoAt ?? _product.revisadoAt,
        );
        _didChange = true;
        _isResending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto reenviado a revisión'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMapper.publicMessage(e,
              fallback: 'Error al reenviar el producto')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejected = _product.isRechazado;
    final pending = _product.isPendiente;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _popWithResult();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Propuesta de producto'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _popWithResult,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusBanner(product: _product),
            const SizedBox(height: 16),
            if (_product.imageUrl.isNotEmpty)
              Center(
                child: ProductImage(
                  imageUrl: _product.imageUrl,
                  width: 160,
                  height: 160,
                ),
              ),
            if (_product.imageUrl.isNotEmpty) const SizedBox(height: 16),
            Text(
              _product.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_product.description.isNotEmpty)
              Text(
                _product.description,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            const SizedBox(height: 16),
            _LabeledBlock(
              label: 'Ingredientes',
              value: _product.ingredientes?.isNotEmpty == true
                  ? _product.ingredientes!
                  : 'Sin ingredientes indicados',
            ),
            const SizedBox(height: 12),
            Text(
              'Puntos: ${_product.puntosValor}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                fontSize: 16,
              ),
            ),
            if (rejected) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Motivo del rechazo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _product.comentarioRevision?.isNotEmpty == true
                          ? _product.comentarioRevision!
                          : 'El administrador no dejó un comentario.',
                      style: const TextStyle(fontSize: 15),
                    ),
                    if (_product.revisadoPorNombre != null) ...[
                      const SizedBox(height: 12),
                      Text('Revisado por: ${_product.revisadoPorNombre}'),
                    ],
                    if (_product.revisadoAt != null) ...[
                      const SizedBox(height: 4),
                      Text(dateFormat.format(_product.revisadoAt!.toLocal())),
                    ],
                  ],
                ),
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'En revisión',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu propuesta está siendo revisada por el administrador.',
                    ),
                    if (_product.comentarioRevision?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Comentario de la revisión anterior',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(_product.comentarioRevision!),
                    ],
                  ],
                ),
              ),
            ],
            if (rejected) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isResending ? null : _editProposal,
                  icon: const Icon(LucideIcons.pencil),
                  label: const Text('Editar propuesta'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isResending ? null : _confirmResend,
                  icon: _isResending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.send),
                  label: Text(
                      _isResending ? 'Reenviando...' : 'Reenviar a revisión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final rejected = product.isRechazado;
    final color = rejected ? Colors.red : Colors.orange;
    final label = rejected ? 'RECHAZADO' : 'PENDIENTE';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Estado: $label',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: rejected ? Colors.red.shade900 : Colors.orange.shade900,
        ),
      ),
    );
  }
}

class _LabeledBlock extends StatelessWidget {
  const _LabeledBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}
