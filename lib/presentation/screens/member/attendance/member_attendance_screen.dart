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
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF7AC142))));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red))),
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
          // Botón para registrar asistencia manualmente
          if (_availableClubes.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.mapPin),
              onPressed: () => _showManualAttendanceDialog(context),
              tooltip: 'Registrar asistencia',
            ),
        ],
      ),
      body: _asistencias.isEmpty 
        ? _buildEmptyState()
        : RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF7AC142),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _asistencias.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final asistencia = _asistencias[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[50],
                    child: const Icon(LucideIcons.calendarCheck, color: Color(0xFF7AC142)),
                  ),
                  title: Text(asistencia.fechaDia, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${asistencia.clubNombre} • ${asistencia.fechaHora}"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: const Text("Asistió", style: TextStyle(fontSize: 10, color: Colors.green)),
                  ),
                );
              },
            ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.calendarX, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No tienes asistencias registradas aún.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          if (_availableClubes.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () => _showManualAttendanceDialog(context),
              icon: const Icon(LucideIcons.mapPin),
              label: const Text('Registrar Asistencia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7AC142),
                foregroundColor: Colors.white,
              ),
            ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => context.push('/member-qr-scan'),
            icon: const Icon(LucideIcons.qrCode),
            label: const Text('Escanear QR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualAttendanceDialog(BuildContext context) async {
    if (_currentMembership == null || _availableClubes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay clubes disponibles para registrar asistencia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int? selectedClubId;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Registrar Asistencia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selecciona el club donde quieres registrar tu asistencia:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedClubId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                  labelText: 'Club',
                ),
                items: _availableClubes.map<DropdownMenuItem<int>>((club) {
                  return DropdownMenuItem<int>(
                    value: club.id,
                    child: Text(club.nombreClub),
                  );
                }).toList(),
                onChanged: (int? newClubId) {
                  setState(() {
                    selectedClubId = newClubId;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selectedClubId == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7AC142),
                foregroundColor: Colors.white,
              ),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedClubId != null) {
      await _registerManualAttendance(selectedClubId!);
    }
  }

  Future<void> _registerManualAttendance(int clubId) async {
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final membresiaDataSource = Provider.of<MembresiaRemoteDataSource>(context, listen: false);
      
      // Usar la membresía del socio (asistencias globales - cualquier club activo)
      final asistenciaResponse = await membresiaDataSource.registrarAsistencia(
        membresiaId: _currentMembership!.id,
        clubId: clubId,
        latitud: 0.0, // No requerimos geolocalización para registro manual
        longitud: 0.0,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar loading

      // Mostrar éxito con información de racha
      String mensaje = asistenciaResponse.mensaje ?? '¡Asistencia registrada correctamente!';
      if (asistenciaResponse.rachaActual != null) {
        mensaje += '\nRacha actual: ${asistenciaResponse.rachaActual} días';
      }
      if (asistenciaResponse.rachaMaxima != null) {
        mensaje += '\nRacha máxima: ${asistenciaResponse.rachaMaxima} días';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // Recargar datos
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar loading si está abierto
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
