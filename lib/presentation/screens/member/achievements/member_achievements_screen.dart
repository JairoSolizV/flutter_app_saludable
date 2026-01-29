import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../domain/entities/attendance.dart';
import '../../../../domain/entities/club_membership.dart';
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

      if (mounted) {
        setState(() {
          _currentMembership = activeMembership;
          _asistencias = asistencias;
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
                   else
                     _buildLoyaltyCard(),
                   
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

  Widget _buildLoyaltyCard() {
    final int assistCount = _asistencias.length;
    // Lógica de sellos: 10 sellos por tarjeta
    final int stamps = assistCount % 10; 
    final int remaining = 10 - stamps;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10)
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Tarjeta de Fidelidad", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                    Text(_currentMembership?.clubNombre ?? "Club Nutrición", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("$stamps/10 Sellos", style: const TextStyle(color: Color(0xFF7AC142), fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            ),
            const SizedBox(height: 30),
            
            // Grid de Estrellas
            Wrap(
              spacing: 12, // espacio horizontal
              runSpacing: 12, // espacio vertical
              alignment: WrapAlignment.center,
              children: List.generate(10, (index) {
                  final bool isFilled = index < stamps;
                  final bool isGift = index == 9; // El último es premio

                  return Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isFilled ? const Color(0xFF7AC142) : (isGift ? const Color(0xFFFFF3E0) : const Color(0xFFF5F5F5)),
                      shape: BoxShape.circle,
                      border: isGift && !isFilled ? Border.all(color: Colors.orangeAccent, width: 2) : null,
                      boxShadow: isFilled ? [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : null
                    ),
                    child: Icon(
                      isGift ? LucideIcons.gift : LucideIcons.star,
                      color: isFilled ? Colors.white : (isGift ? Colors.orange : Colors.grey[400]),
                      size: 24,
                    ),
                  );
              }),
            ),
            
            const SizedBox(height: 20),
            Center(
              child: Text(
                remaining > 0 
                  ? "¡Solo $remaining consumos más para tu recompensa sorpresa!" 
                  : "¡Felicidades! Tienes una recompensa disponible.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
        ],
      ),
    );
  }

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
