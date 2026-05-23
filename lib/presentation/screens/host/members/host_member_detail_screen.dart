import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../data/datasources/remote/compras_remote_data_source.dart';
import '../../../../domain/entities/attendance.dart';
import '../../../../domain/entities/club_membership.dart';
import '../../../../domain/entities/compra_manual.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

class HostMemberDetailScreen extends StatefulWidget {
  final int membresiaId;
  final String memberName;

  const HostMemberDetailScreen({
    super.key,
    required this.membresiaId,
    required this.memberName,
  });

  @override
  State<HostMemberDetailScreen> createState() => _HostMemberDetailScreenState();
}

class _HostMemberDetailScreenState extends State<HostMemberDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingAttendances = true;
  bool _loadingPurchases = true;
  bool _loadingReferidos = true;
  bool _loadingCombo = true;
  bool _haConsumidoCombo = false;
  List<Attendance> _attendances = [];
  List<CompraManual> _purchases = [];
  List<ClubMembership> _referidos = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadAttendances(), _loadPurchases(), _loadReferidos(), _loadEstadoCombo()]);
  }

  Future<void> _loadAttendances() async {
    try {
      final ds = Provider.of<MembresiaRemoteDataSource>(context, listen: false);
      final list = await ds.getAsistencias(widget.membresiaId);
      if (mounted) setState(() { _attendances = list; _loadingAttendances = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingAttendances = false);
    }
  }

  Future<void> _loadPurchases() async {
    try {
      final ds = Provider.of<ComprasRemoteDataSource>(context, listen: false);
      final list = await ds.getComprasPorMembresia(widget.membresiaId);
      if (mounted) setState(() { _purchases = list; _loadingPurchases = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingPurchases = false);
    }
  }

  Future<void> _loadReferidos() async {
    try {
      final ds = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final list = await ds.getReferidosPorMembresia(widget.membresiaId);
      if (mounted) setState(() { _referidos = list; _loadingReferidos = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingReferidos = false);
    }
  }

  Future<void> _loadEstadoCombo() async {
    try {
      final ds = Provider.of<MembresiaRemoteDataSource>(context, listen: false);
      final estado = await ds.getEstadoCombo(widget.membresiaId);
      if (mounted) {
        setState(() {
          _haConsumidoCombo = estado.containsKey('haConsumidoCombo') ? estado['haConsumidoCombo'] : false;
          _loadingCombo = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCombo = false);
    }
  }

  Future<void> _registrarAsistenciaManual() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Asistencia Manual'),
        content: const Text('¿Confirmar asistencia de hoy para este socio?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final ds = Provider.of<MembresiaRemoteDataSource>(context, listen: false);
      final attendance = await ds.registrarAsistenciaManual(membresiaId: widget.membresiaId);
      if (!mounted) return;
      setState(() => _attendances.insert(0, attendance));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asistencia registrada'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.memberName.isNotEmpty ? widget.memberName : 'Detalle del Socio'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          indicatorColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(LucideIcons.calendarCheck), text: 'Asistencias'),
            Tab(icon: Icon(LucideIcons.shoppingBag), text: 'Compras'),
            Tab(icon: Icon(LucideIcons.users), text: 'Referidos'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_loadingCombo)
            const LinearProgressIndicator(color: AppTheme.primaryColor)
          else
            Card(
              margin: const EdgeInsets.all(16),
              child: ListTile(
                leading: Icon(_haConsumidoCombo ? Icons.check_circle : Icons.warning,
                              color: _haConsumidoCombo ? Colors.green : Colors.orange),
                title: Text(_haConsumidoCombo ? 'Combo consumido' : 'Pendiente de combo'),
                subtitle: Text(_haConsumidoCombo
                    ? 'El socio ya ha consumido al menos 1 combo.'
                    : 'El socio aún no ha consumido un combo. Las asistencias pueden estar restringidas.'),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
          _AsistenciasTab(
            loading: _loadingAttendances,
            attendances: _attendances,
            onRegister: _registrarAsistenciaManual,
          ),
          _ComprasTab(
            loading: _loadingPurchases,
            purchases: _purchases,
            onRegister: () async {
              final club = await Provider.of<ClubRemoteDataSource>(context, listen: false).getMyClub();
              if (!mounted || club == null) return;
              await context.push(
                '/host/members/${widget.membresiaId}/purchases/new',
                extra: {'clubId': club.id},
              );
              _loadPurchases();
            },
          ),
          _ReferidosTab(loading: _loadingReferidos, referidos: _referidos),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AsistenciasTab extends StatelessWidget {
  final bool loading;
  final List<Attendance> attendances;
  final VoidCallback onRegister;

  const _AsistenciasTab({required this.loading, required this.attendances, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRegister,
              icon: const Icon(LucideIcons.plusCircle, color: AppTheme.primaryColor),
              label: const Text('Registrar Asistencia Manual', style: TextStyle(color: AppTheme.primaryColor)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryColor)),
            ),
          ),
        ),
        Expanded(child: loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : attendances.isEmpty
              ? const Center(child: Text('Sin asistencias registradas', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: attendances.length,
                  itemBuilder: (_, i) {
                    final a = attendances[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Icon(LucideIcons.checkCircle, color: AppTheme.primaryColor, size: 20),
                      ),
                      title: Text(a.fechaDia, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(a.fechaHora),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(a.estado, style: TextStyle(color: Colors.green.shade800, fontSize: 12)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ComprasTab extends StatelessWidget {
  final bool loading;
  final List<CompraManual> purchases;
  final VoidCallback onRegister;

  const _ComprasTab({required this.loading, required this.purchases, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs. ', decimalDigits: 2);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRegister,
              icon: const Icon(LucideIcons.plusCircle, color: AppTheme.primaryColor),
              label: const Text('Registrar Compra', style: TextStyle(color: AppTheme.primaryColor)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryColor)),
            ),
          ),
        ),
        Expanded(child: loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : purchases.isEmpty
              ? const Center(child: Text('Sin compras registradas', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: purchases.length,
                  itemBuilder: (_, i) {
                    final p = purchases[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFF8E1),
                        child: Icon(LucideIcons.shoppingBag, color: Colors.orange, size: 20),
                      ),
                      title: Text(p.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(p.fecha),
                      trailing: Text(
                        fmt.format(p.monto),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ReferidosTab extends StatelessWidget {
  final bool loading;
  final List<ClubMembership> referidos;

  const _ReferidosTab({required this.loading, required this.referidos});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    if (referidos.isEmpty) {
      return const Center(child: Text('Este socio aún no ha referido a nadie', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: referidos.length,
      itemBuilder: (_, i) {
        final r = referidos[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                r.usuarioNombre.isNotEmpty ? r.usuarioNombre[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(r.usuarioNombre, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${r.numeroSocio} · ${r.nivelNombre}'),
            trailing: Text('${r.puntosAcumulados} pts', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
