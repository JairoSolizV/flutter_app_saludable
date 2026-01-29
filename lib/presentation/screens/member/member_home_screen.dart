import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/loyalty_card.dart';
import '../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../domain/entities/attendance.dart';
import '../../../domain/entities/club_membership.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  bool _isLoading = true;
  ClubMembership? _activeMembership;
  List<Attendance> _asistencias = [];

  @override
  void initState() {
    super.initState();
    _loadLoyaltyData();
  }

  Future<void> _loadLoyaltyData() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;
      
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final dataSource = Provider.of<MembresiaRemoteDataSource>(context, listen: false);
      
      // 1. Obtener Membresías
      final membresias = await dataSource.getMembresiasPorUsuario(int.parse(user.id));
      
      if (membresias.isNotEmpty) {
        final membership = membresias.first;
        // 2. Asistencias para la membresía activa
        final asistencias = await dataSource.getAsistencias(membership.id);
        
        if (mounted) {
          setState(() {
            _activeMembership = membership;
            _asistencias = asistencias;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      // Silently fail or minimal error state for Home
      print("Error loading home data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
           final user = userProvider.currentUser;
           final displayName = user?.name.split(' ').first ?? 'Invitado';
           final initials = user?.name.isNotEmpty == true ? user!.name.substring(0, 2).toUpperCase() : '?';

           return CustomScrollView(
            slivers: [
              // Header Flotante
              SliverAppBar(
                backgroundColor: const Color(0xFF7AC142),
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Text(
                    'Hola, $displayName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7AC142), Color(0xFF6BB032)],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(LucideIcons.qrCode, color: Colors.white),
                    onPressed: () => context.push('/member-qr-scan'),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.bell, color: Colors.white),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(initials, style: const TextStyle(color: Color(0xFF7AC142))),
                  ),
                  const SizedBox(width: 16),
                ],
              ),

              // Contenido
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Tarjeta de Fidelidad Dinámica
                      if (_isLoading)
                         const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else if (_activeMembership != null)
                        LoyaltyCard(
                           stamps: _asistencias.length % 10,
                           maxStamps: 10,
                           clubName: _activeMembership!.clubNombre,
                        )
                      else
                        // Estado vacío si no hay membresía
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: const [
                               Icon(LucideIcons.info, color: Colors.grey),
                               SizedBox(width: 10),
                               Expanded(child: Text("Únete a un club para ver tu tarjeta de fidelidad.", style: TextStyle(color: Colors.grey))),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 24),

                      // Botón CTA (Hacer Pedido)
                      InkWell(
                        onTap: () => context.push('/member-orders/new'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF333333),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7AC142),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.shoppingBag, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hacer Pedido',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Pide por adelantado y recoge',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}
