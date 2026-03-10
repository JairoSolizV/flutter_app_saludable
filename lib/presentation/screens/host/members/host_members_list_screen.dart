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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user == null) {
        throw Exception("Usuario no autenticado");
      }

      // 1. Obtener el Club del Anfitrión
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final club = await clubDataSource.getMyClub();

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
        title: Text('Socios del Club'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _buildBody(),
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

    // Filtrar miembros
    final filteredMembers = _members.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.usuarioNombre.toLowerCase().contains(_searchQuery) ||
             m.numeroSocio.toLowerCase().contains(_searchQuery);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadMembers,
      color: const Color(0xFF7AC142),
      child: Column(
        children: [
          // Encabezado con conteo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.users, color: Color(0xFF7AC142), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Total de Socios: ${_members.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7AC142).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_members.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7AC142),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Barra de Búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o número...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          
          // Lista de socios
          Expanded(
            child: filteredMembers.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron socios',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = filteredMembers[index];
                      return _buildMemberCard(member);
                    },
                  ),
          ),
        ],
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
      child: InkWell(
        onTap: () => _showMemberDetails(member),
        borderRadius: BorderRadius.circular(16),
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
              // Los puntos se actualizan automáticamente en el backend cuando se registra una asistencia
              // No se calculan ni actualizan manualmente en el frontend
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
      ),
    );
  }

  void _showMemberDetails(ClubMembership member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF7AC142).withOpacity(0.1),
                child: Text(
                  member.usuarioNombre.isNotEmpty ? member.usuarioNombre[0].toUpperCase() : '?',
                  style: const TextStyle(color: Color(0xFF7AC142), fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                member.usuarioNombre,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50], 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Text(
                  member.nivelNombre,
                  style: TextStyle(fontSize: 14, color: Colors.green[800], fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow(LucideIcons.hash, 'Número de Socio', member.numeroSocio),
              const Divider(height: 24),
              _buildDetailRow(LucideIcons.calendar, 'Fecha de Registro', member.fechaRegistro),
              const Divider(height: 24),
              _buildDetailRow(LucideIcons.star, 'Puntos Acumulados', '${member.puntosAcumulados} pts'),
              const Divider(height: 24),
              _buildDetailRow(LucideIcons.info, 'Estado', member.estado),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7AC142),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cerrar', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
      ],
    );
  }
}

