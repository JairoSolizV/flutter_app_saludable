import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../domain/entities/attendance.dart';
import '../../../../domain/entities/club_membership.dart';
import '../../../providers/user_provider.dart';
import '../../../../domain/entities/user.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';

class MemberAttendanceScreen extends StatefulWidget {
  const MemberAttendanceScreen({super.key});

  @override
  State<MemberAttendanceScreen> createState() => _MemberAttendanceScreenState();
}

class _MemberAttendanceScreenState extends State<MemberAttendanceScreen> {
  bool _isLoading = true;
  String? _error;
  List<Attendance> _asistencias = [];
  ClubMembership? _currentMembership;
  User? _currentUser;
  List<Club> _availableClubes = []; // Clubes del HUB disponibles para asistencia
  int? _hubId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (mounted) setState(() => _error = null);
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
      final activeMembership = membresias.first;
      
      // 2. Obtener Asistencias de esa membresía
      final asistencias = await dataSource.getAsistencias(activeMembership.id);

      // 3. Cargar todos los clubes activos (asistencias globales - sin restricción de HUB)
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      // Obtener todos los clubes públicos (activos)
      final clubes = await clubDataSource.getClubes();
      
      if (mounted) {
        setState(() {
          _currentMembership = activeMembership;
          _asistencias = asistencias.reversed.toList();
          _availableClubes = clubes; // Todos los clubes activos
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
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
    }

    if (_error != null) {
      return Scaffold(
        body: RefreshableScrollView(
          onRefresh: _loadData,
          child: Text("Error: $_error", style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Mi Asistencia"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // Botón para escanear QR
          IconButton(
            icon: const Icon(LucideIcons.qrCode),
            onPressed: () => context.push('/member-qr-scan'),
            tooltip: 'Escanear QR',
          ),
        ],
      ),
      body: _asistencias.isEmpty 
        ? _buildEmptyState()
        : RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.primaryColor,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _asistencias.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final asistencia = _asistencias[index];
                // Extraer solo la hora (HH:mm) de fechaHora
                String hora = '';
                try {
                  // fechaHora puede venir como "2026-02-17 20:30:00" o "17/02/2026 20:30:00"
                  if (asistencia.fechaHora.contains(' ')) {
                    final parts = asistencia.fechaHora.split(' ');
                    if (parts.length >= 2) {
                      final timePart = parts[1]; // "20:30:00"
                      final timeComponents = timePart.split(':');
                      if (timeComponents.length >= 2) {
                        hora = '${timeComponents[0]}:${timeComponents[1]}'; // "20:30"
                      }
                    }
                  }
                } catch (e) {
                  hora = asistencia.fechaHora; // Fallback si no se puede parsear
                }
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.calendarCheck,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      asistencia.fechaDia,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF333333),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.mapPin,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  asistencia.clubNombre,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (hora.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.clock,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hora,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: const Text(
                        "Asistió",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshableScrollView(
      onRefresh: _loadData,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.calendarX, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No tienes asistencias registradas aún.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/member-qr-scan'),
            icon: const Icon(LucideIcons.qrCode),
            label: const Text('Escanear QR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
