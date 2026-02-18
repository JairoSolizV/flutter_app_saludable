import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../domain/entities/attendance.dart';
import '../../../../domain/entities/club_membership.dart';
import '../../../../domain/entities/logro.dart';
import '../../../../domain/entities/membresia_logro.dart';
import '../../../providers/user_provider.dart';
import '../../../../domain/entities/user.dart';

class MemberAchievementsScreen extends StatefulWidget {
  const MemberAchievementsScreen({super.key});

  @override
  State<MemberAchievementsScreen> createState() => _MemberAchievementsScreenState();
}

class _MemberAchievementsScreenState extends State<MemberAchievementsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Attendance> _asistencias = [];
  ClubMembership? _currentMembership;
  User? _currentUser;
  List<Logro> _allLogros = [];
  List<MembresiaLogro> _obtainedLogros = [];

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
      
      // 2. Obtener Asistencias de esa membresía (para calcular puntos)
      final asistencias = await dataSource.getAsistencias(activeMembership.id);
      
      // 3. Obtener todos los logros disponibles
      final allLogros = await dataSource.getLogros();
      
      // 4. Obtener logros obtenidos por el socio
      final obtainedLogros = await dataSource.getLogrosByMembresia(activeMembership.id);

      if (mounted) {
        setState(() {
          _currentMembership = activeMembership;
          _asistencias = asistencias;
          _allLogros = allLogros;
          _obtainedLogros = obtainedLogros;
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
                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   if (_currentMembership == null)
                     _buildNoMembershipCard()
                   else ...[
                     // Puntos acumulados (cantidad de asistencias)
                     _buildPointsCard(),
                     const SizedBox(height: 24),
                     // Logros obtenidos
                     _buildObtainedAchievementsSection(),
                     const SizedBox(height: 24),
                     // Logros disponibles
                     _buildAvailableAchievementsSection(),
                   ],
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

  Widget _buildPointsCard() {
    // Usar puntosAcumulados del backend (se actualiza automáticamente con cada asistencia)
    final int puntosAcumulados = _currentMembership?.puntosAcumulados ?? 0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7AC142), Color(0xFF5A9A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            LucideIcons.star,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          const Text(
            'Puntos Acumulados',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$puntosAcumulados',
            style: const TextStyle(
              fontSize: 48,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${puntosAcumulados == 1 ? 'asistencia' : 'asistencias'} registrada${puntosAcumulados == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObtainedAchievementsSection() {
    if (_obtainedLogros.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Logros Obtenidos',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: _obtainedLogros.length,
          itemBuilder: (context, index) {
            final membresiaLogro = _obtainedLogros[index];
            return _buildAchievementCard(
              logro: membresiaLogro.logro,
              isObtained: true,
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvailableAchievementsSection() {
    // Filtrar logros que aún no se han obtenido
    final obtainedLogroIds = _obtainedLogros.map((ml) => ml.logro.id).toSet();
    final availableLogros = _allLogros.where((logro) => !obtainedLogroIds.contains(logro.id)).toList();

    if (availableLogros.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Logros Disponibles',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Completa los requisitos para desbloquear estos logros',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: availableLogros.length,
          itemBuilder: (context, index) {
            return _buildAchievementCard(
              logro: availableLogros[index],
              isObtained: false,
            );
          },
        ),
      ],
    );
  }

  Widget _buildAchievementCard({required Logro logro, required bool isObtained}) {
    String requisitoTexto = _getRequisitoTexto(logro.tipoRequisito);
    
    return Container(
      decoration: BoxDecoration(
        color: isObtained ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isObtained ? const Color(0xFF7AC142) : Colors.grey[300]!,
          width: isObtained ? 2 : 1,
        ),
        boxShadow: isObtained
            ? [
                BoxShadow(
                  color: const Color(0xFF7AC142).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isObtained
                    ? const Color(0xFF7AC142).withOpacity(0.1)
                    : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                logro.iconoUrl != null && logro.iconoUrl!.isNotEmpty
                    ? LucideIcons.award
                    : LucideIcons.trophy,
                color: isObtained ? const Color(0xFF7AC142) : Colors.grey[400],
                size: 32,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              logro.nombre,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isObtained ? const Color(0xFF333333) : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (requisitoTexto.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                requisitoTexto,
                style: TextStyle(
                  fontSize: 10,
                  color: isObtained ? Colors.grey[600] : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (isObtained) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7AC142).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Obtenido',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF7AC142),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getRequisitoTexto(String? tipoRequisito) {
    if (tipoRequisito == null || tipoRequisito.isEmpty) {
      return '';
    }
    
    switch (tipoRequisito.toUpperCase()) {
      case 'RACHA_3':
        return 'Racha de 3 días';
      case 'RACHA_7':
        return 'Racha de 7 días';
      case 'RACHA_14':
        return 'Racha de 14 días';
      case 'ASISTENCIAS_5':
        return '5 asistencias';
      case 'ASISTENCIAS_10':
        return '10 asistencias';
      case 'ASISTENCIAS_20':
        return '20 asistencias';
      default:
        return tipoRequisito.replaceAll('_', ' ');
    }
  }

}
