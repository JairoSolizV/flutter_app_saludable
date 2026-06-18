import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../data/datasources/remote/pre_socio_remote_data_source.dart';
import '../../../../domain/entities/pre_socio.dart';
import '../../../../domain/entities/mision_pre_socio.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';

class HostPreSocioDetailScreen extends StatefulWidget {
  final int preSocioId;
  final int clubId;

  const HostPreSocioDetailScreen({
    super.key,
    required this.preSocioId,
    required this.clubId,
  });

  @override
  State<HostPreSocioDetailScreen> createState() => _HostPreSocioDetailScreenState();
}

class _HostPreSocioDetailScreenState extends State<HostPreSocioDetailScreen> {
  bool _isLoading = true;
  PreSocio? _preSocio;
  String? _error;
  final Set<int> _loadingMisions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final ds = Provider.of<PreSocioRemoteDataSource>(context, listen: false);
      final list = await ds.getPreSocios(widget.clubId);
      final found = list.where((p) => p.id == widget.preSocioId).toList();
      if (found.isEmpty) throw Exception('PreSocio no encontrado.');
      if (mounted) setState(() { _preSocio = found.first; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _incrementarProgreso(MisionPreSocio mision) async {
    if (_loadingMisions.contains(mision.id)) return;
    setState(() => _loadingMisions.add(mision.id));
    try {
      final ds = Provider.of<PreSocioRemoteDataSource>(context, listen: false);
      final updated = await ds.incrementarProgreso(mision.id);
      if (!mounted) return;
      setState(() {
        final misiones = _preSocio!.misiones.map((m) => m.id == updated.id ? updated : m).toList();
        _preSocio = PreSocio(
          id: _preSocio!.id, clubId: _preSocio!.clubId,
          nombre: _preSocio!.nombre, telefono: _preSocio!.telefono,
          referidoPorMembresiaId: _preSocio!.referidoPorMembresiaId,
          referidoPorNombre: _preSocio!.referidoPorNombre,
          fechaCreacion: _preSocio!.fechaCreacion, estado: _preSocio!.estado,
          misiones: misiones,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Progreso actualizado: ${updated.progresoActual}/${updated.metaCantidad}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loadingMisions.remove(mision.id));
    }
  }

  Future<void> _eliminarMision(MisionPreSocio mision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar misión'),
        content: Text('¿Eliminar "${mision.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final ds = Provider.of<PreSocioRemoteDataSource>(context, listen: false);
      await ds.eliminarMision(mision.id);
      if (!mounted) return;
      setState(() {
        final misiones = _preSocio!.misiones.where((m) => m.id != mision.id).toList();
        _preSocio = PreSocio(
          id: _preSocio!.id, clubId: _preSocio!.clubId,
          nombre: _preSocio!.nombre, telefono: _preSocio!.telefono,
          referidoPorMembresiaId: _preSocio!.referidoPorMembresiaId,
          referidoPorNombre: _preSocio!.referidoPorNombre,
          fechaCreacion: _preSocio!.fechaCreacion, estado: _preSocio!.estado,
          misiones: misiones,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _iniciarConversion() async {
    if (_preSocio == null) return;
    await context.push('/host-scan', extra: {
      'preSocioId': _preSocio!.id,
      'prefilledReferralId': _preSocio!.referidoPorMembresiaId,
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
    if (_error != null) return Scaffold(
      appBar: AppBar(title: const Text('Ficha de PreSocio'), backgroundColor: Colors.white, foregroundColor: Colors.black87),
      body: RefreshableScrollView(
        onRefresh: _load,
        child: Text(_error!, style: const TextStyle(color: Colors.grey)),
      ),
    );

    final p = _preSocio!;
    final isConvertido = p.estado == 'CONVERTIDO';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(p.nombre),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(p),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Misiones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (!isConvertido)
                  TextButton.icon(
                    onPressed: () async {
                      await context.push('/host/pre-socios/${p.id}/misiones/new');
                      _load();
                    },
                    icon: const Icon(Icons.add, color: AppTheme.primaryColor),
                    label: const Text('Agregar', style: TextStyle(color: AppTheme.primaryColor)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (p.misiones.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                ),
                child: const Center(child: Text('No hay misiones definidas.', style: TextStyle(color: Colors.grey))),
              )
            else
              ...p.misiones.map((m) => _MisionCard(
                mision: m,
                isReadOnly: isConvertido,
                isLoadingProgress: _loadingMisions.contains(m.id),
                onIncrement: () => _incrementarProgreso(m),
                onDelete: () => _eliminarMision(m),
              )),
            if (!isConvertido && p.todasMisionesCompletas && p.misiones.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(LucideIcons.trophy, color: AppTheme.primaryColor, size: 40),
                    const SizedBox(height: 8),
                    const Text('¡Todas las misiones completadas!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C5E1A))),
                    const SizedBox(height: 4),
                    const Text('El pre-socio está listo para ser socio oficial.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _iniciarConversion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('CONVERTIR A SOCIO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(PreSocio p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: Text(
                  p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppTheme.primaryColor, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(p.telefono, style: const TextStyle(color: Colors.grey)),
                ]),
              ),
              _EstadoBadge(estado: p.estado),
            ],
          ),
          if (p.referidoPorNombre != null) ...[
            const Divider(height: 20),
            Row(children: [
              const Icon(LucideIcons.userCheck, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text('Referido por: ${p.referidoPorNombre}', style: const TextStyle(color: Colors.grey)),
            ]),
          ],
          const Divider(height: 20),
          Row(children: [
            const Icon(LucideIcons.calendar, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text('Desde: ${p.fechaCreacion}', style: const TextStyle(color: Colors.grey)),
          ]),
        ],
      ),
    );
  }
}

class _MisionCard extends StatelessWidget {
  final MisionPreSocio mision;
  final bool isReadOnly;
  final bool isLoadingProgress;
  final VoidCallback onIncrement;
  final VoidCallback onDelete;

  const _MisionCard({
    required this.mision,
    required this.isReadOnly,
    required this.isLoadingProgress,
    required this.onIncrement,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (mision.porcentaje * 100).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        border: mision.completada ? Border.all(color: Colors.green.shade300) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mision.nombre,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    decoration: mision.completada ? TextDecoration.lineThrough : null,
                    color: mision.completada ? Colors.grey : Colors.black87,
                  ),
                ),
              ),
              if (mision.completada)
                const Icon(LucideIcons.checkCircle, color: AppTheme.primaryColor, size: 20)
              else
                Text(
                  '${mision.progresoActual} / ${mision.metaCantidad}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: mision.porcentaje,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                mision.completada ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.6),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('$pct%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (mision.descripcion != null && mision.descripcion!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(child: Text(mision.descripcion!, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              if (mision.fechaLimite != null) ...[
                const Spacer(),
                Icon(LucideIcons.clock, size: 12, color: Colors.orange.shade400),
                const SizedBox(width: 4),
                Text('Vence: ${mision.fechaLimite}', style: TextStyle(fontSize: 11, color: Colors.orange.shade600)),
              ],
            ],
          ),
          if (!isReadOnly) ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!mision.completada)
                  isLoadingProgress
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor))
                      : ElevatedButton.icon(
                          onPressed: onIncrement,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('+1 Progreso', style: TextStyle(fontSize: 12)),
                        ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    final isConvertido = estado == 'CONVERTIDO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConvertido ? Colors.blue.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isConvertido ? Colors.blue.shade200 : Colors.orange.shade200),
      ),
      child: Text(
        isConvertido ? 'Convertido' : 'En seguimiento',
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: isConvertido ? Colors.blue.shade700 : Colors.orange.shade700,
        ),
      ),
    );
  }
}
