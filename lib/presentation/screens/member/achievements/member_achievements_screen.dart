import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../domain/entities/attendance.dart';
import '../../../../domain/entities/club_membership.dart';
import '../../../providers/user_provider.dart';
import '../../../../domain/entities/user.dart';
import '../../../../domain/entities/logro.dart';
import '../../../../data/datasources/remote/logro_remote_data_source.dart';
import '../../../widgets/composite_loyalty_card.dart';

class MemberAchievementsScreen extends StatefulWidget {
  const MemberAchievementsScreen({super.key});

  @override
  State<MemberAchievementsScreen> createState() => _MemberAchievementsScreenState();
}

class _MemberAchievementsScreenState extends State<MemberAchievementsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Attendance> _asistencias = [];
  List<LogroProgreso> _progresos = [];
  ClubMembership? _currentMembership;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user == null) throw Exception("Usuario no autenticado");
      
      setState(() => _currentUser = user);

      final dataSource = Provider.of<MembresiaRemoteDataSource>(context, listen: false);

      // 1. Obtener Membresías del usuario
      final membresias = await dataSource.getMembresiasPorUsuario(int.parse(user.id));
      
      if (membresias.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Por ahora tomamos la primera membresía activa
      // En el futuro podríamos permitir seleccionar club
      final activeMembership = membresias.first;
      
      // 2. Obtener Asistencias de esa membresía
      final asistencias = await dataSource.getAsistencias(activeMembership.id);

      // 3. Obtener el Progreso de Retos Compuestos del Socio
      final logroDS = Provider.of<LogroRemoteDataSource>(context, listen: false);
      final progresos = await logroDS.getProgresoSocio(activeMembership.id);

      if (mounted) {
        setState(() {
          _currentMembership = activeMembership;
          _asistencias = asistencias;
          _progresos = progresos;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF7AC142))));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red))),
      );
    }
    
    // Header Verde con "Hola, Usuario"
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF7AC142),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
              title: Text(
                'Hola, ${_currentUser?.name.split(" ").first ?? "Socio"}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            actions: [
               Container(
                 margin: const EdgeInsets.only(right: 16),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   shape: BoxShape.circle,
                 ),
                 child: IconButton(
                    icon: Text(_currentUser?.name.substring(0,2).toUpperCase() ?? "US", style: const TextStyle(color: Color(0xFF7AC142), fontWeight: FontWeight.bold)),
                    onPressed: () {},
                 ),
               )
            ],
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                   if (_currentMembership == null)
                     _buildNoMembershipCard()
                   else if (_progresos.isEmpty)
                     const Padding(
                       padding: EdgeInsets.symmetric(vertical: 40),
                       child: Center(
                         child: Text("No hay retos activos en este club aún.", style: TextStyle(color: Colors.grey)),
                       ),
                     )
                   else
                     ..._progresos.map((progreso) => Padding(
                           padding: const EdgeInsets.only(bottom: 20),
                           child: CompositeLoyaltyCard(
                             progreso: progreso,
                             clubName: _currentMembership?.clubNombre ?? "Mi Club",
                           ),
                         ))
                         .toList(),
                   
                   const SizedBox(height: 30),
                   
                   if (_asistencias.isNotEmpty)
                    _buildHistoryList(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNoMembershipCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: const [
            Icon(LucideIcons.frown, size: 50, color: Colors.grey),
            SizedBox(height: 10),
            Text("Aún no eres socio de ningún club.", textAlign: TextAlign.center, style: TextStyle( fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // _buildLoyaltyCard removed in favor of reusable LoyaltyCard widget

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         const Padding(
           padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
           child: Text("Historial de Asistencias", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
         ),
         ListView.builder(
           shrinkWrap: true,
           physics: const NeverScrollableScrollPhysics(),
           itemCount: _asistencias.length > 5 ? 5 : _asistencias.length, // Mostrar últimos 5
           itemBuilder: (context, index) {
              final asistencia = _asistencias[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                  child: const Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
                ),
                title: Text(asistencia.fechaDia, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text("${asistencia.clubNombre} • ${asistencia.fechaHora}", style: const TextStyle(fontSize: 12)),
              );
           },
         )
      ],
    );
  }
}
