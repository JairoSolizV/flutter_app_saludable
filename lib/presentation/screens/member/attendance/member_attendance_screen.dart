import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../data/datasources/remote/membresia_remote_data_source.dart';
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

      if (mounted) {
        setState(() {
          _currentMembership = activeMembership;
          _asistencias = asistencias.reversed.toList(); // Mostrar más recientes primero? Backend suele dar orden cronológico
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
        children: const [
          Icon(LucideIcons.calendarX, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("No tienes asistencias registradas aún.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
