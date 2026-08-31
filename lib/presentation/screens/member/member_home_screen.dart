import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/member_summary_card.dart';
import '../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  bool _isLoading = true;
  ClubMembership? _activeMembership;
  int? _attendanceCount;

  @override
  void initState() {
    super.initState();
    _loadMemberSummaryData();
  }

  Future<void> _loadMemberSummaryData() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final dataSource =
          Provider.of<MembresiaRemoteDataSource>(context, listen: false);

      final membresias =
          await dataSource.getMembresiasPorUsuario(int.parse(user.id));

      if (membresias.isEmpty) {
        if (mounted) {
          setState(() {
            _activeMembership = null;
            _attendanceCount = null;
            _isLoading = false;
          });
        }
        return;
      }

      final membership = membresias.first;
      int? attendanceCount;
      try {
        final asistencias = await dataSource.getAsistencias(membership.id);
        attendanceCount = asistencias.length;
      } catch (e) {
        logDebug('Error loading attendances for home summary: $e');
        attendanceCount = null;
      }

      if (mounted) {
        setState(() {
          _activeMembership = membership;
          _attendanceCount = attendanceCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      logDebug('Error loading home summary data: $e');
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
          final initials = user?.name.isNotEmpty == true
              ? user!.name.substring(0, 2).toUpperCase()
              : '?';

          return RefreshIndicator(
            onRefresh: _loadMemberSummaryData,
            color: AppTheme.primaryColor,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: AppTheme.primaryColor,
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
                          colors: AppTheme.primaryGradient,
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(LucideIcons.qrCode, color: Colors.white),
                      onPressed: () => context.push('/member-qr-scan'),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(initials,
                          style: const TextStyle(color: AppTheme.primaryColor)),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_activeMembership != null)
                          MemberSummaryCard(
                            clubName: _activeMembership!.clubNombre,
                            memberNumber: _activeMembership!.numeroSocio,
                            points: _activeMembership!.puntosAcumulados,
                            attendanceCount: _attendanceCount,
                            membershipLevel: _activeMembership!.nivelNombre,
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: const [
                                Icon(LucideIcons.info, color: Colors.grey),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Únete a un club para ver la información de tu membresía.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (_activeMembership != null)
                          InkWell(
                            onTap: () async {
                              final result =
                                  await context.push('/member-qr-scan');
                              if (result == true || mounted) {
                                _loadMemberSummaryData();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
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
                                      color: Colors.white.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(LucideIcons.qrCode,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Registrar Asistencia',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'Escanear QR del anfitrión',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward,
                                      color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        if (_activeMembership != null)
                          const SizedBox(height: 16),
                        InkWell(
                          onTap: () => context.push('/member-events'),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppTheme.primaryColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
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
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.calendar,
                                      color: AppTheme.primaryColor),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Eventos',
                                        style: TextStyle(
                                          color: Color(0xFF2C5E1A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Ver eventos programados',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward,
                                    color: AppTheme.primaryColor),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () {
                            if (_activeMembership != null) {
                              context.push('/member-orders/new/club-products',
                                  extra: {
                                    'clubId': _activeMembership!.clubId,
                                    'clubNombre':
                                        _activeMembership!.clubNombre,
                                  });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('No tienes un club asociado')),
                              );
                            }
                          },
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
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.shoppingBag,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                const Icon(Icons.arrow_forward,
                                    color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
