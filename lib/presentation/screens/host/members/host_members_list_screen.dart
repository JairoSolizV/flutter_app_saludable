import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../domain/entities/club_membership.dart';
import '../../../providers/user_provider.dart';

class HostMembersListScreen extends StatefulWidget {
  const HostMembersListScreen({super.key});

  @override
  State<HostMembersListScreen> createState() => _HostMembersListScreenState();
}

class _HostMembersListScreenState extends State<HostMembersListScreen> {
  bool _isLoading = true;
  List<ClubMembership> _members = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user == null) {
        throw Exception("Usuario no autenticado");
      }

      // 1. Obtener el Club del Anfitrión
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final club = await clubDataSource.getClubByHostId(int.parse(user.id));

      if (club == null) {
        throw Exception("No se encontró un club asociado a este anfitrión.");
      }

      // 2. Obtener los Socios del Club
      final members = await clubDataSource.getClubMembers(club.id);

      if (mounted) {
        setState(() {
          _members = members;
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
    return Scaffold(
      backgroundColor: Colors.grey[50], // Fondo suave
      appBar: AppBar(
        title: const Text('Socios del Club'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Función de registro manual próximamente')),
          );
        },
        backgroundColor: const Color(0xFF7AC142),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7AC142)));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.alertCircle, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadMembers();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7AC142), 
                  foregroundColor: Colors.white
                ),
                child: const Text("Reintentar"),
              )
            ],
          ),
        ),
      );
    }

    if (_members.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay socios registrados aún.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMembers,
      color: const Color(0xFF7AC142),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          return _buildMemberCard(member);
        },
      ),
    );
  }

  Widget _buildMemberCard(ClubMembership member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF7AC142).withOpacity(0.1),
          child: Text(
            member.usuarioNombre.isNotEmpty ? member.usuarioNombre[0].toUpperCase() : '?',
            style: const TextStyle(color: Color(0xFF7AC142), fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          member.usuarioNombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50], // Color suave para nivel
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green[100]!),
                  ),
                  child: Text(
                    member.nivelNombre,
                    style: TextStyle(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  member.numeroSocio, // "SCZ-0001"
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              "Puntos",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              "${member.puntosAcumulados}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF7AC142),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

