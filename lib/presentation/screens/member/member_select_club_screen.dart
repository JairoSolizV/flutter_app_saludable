import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';

class MemberSelectClubScreen extends StatefulWidget {
  const MemberSelectClubScreen({super.key});

  @override
  State<MemberSelectClubScreen> createState() => _MemberSelectClubScreenState();
}

class _MemberSelectClubScreenState extends State<MemberSelectClubScreen> {
  List<Club> _clubes = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadClubes();
  }

  Future<void> _loadClubes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      // getClubes() ya devuelve solo clubes ACTIVOS o APROBADO desde /api/public/clubes
      // No necesitamos filtrar adicionalmente, pero mantenemos el filtro por si acaso
      final clubes = await clubDataSource.getClubes();
      
      // El endpoint público ya devuelve solo ACTIVOS/APROBADO, pero filtramos por seguridad
      // para asegurar que solo mostramos ACTIVOS
      final clubesActivos = clubes.where((club) => 
        club.estado.toUpperCase() == 'ACTIVO' || club.estado.toUpperCase() == 'APROBADO'
      ).toList();

      if (mounted) {
        setState(() {
          _clubes = clubesActivos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<Club> get _filteredClubes {
    if (_searchQuery.isEmpty) {
      return _clubes;
    }
    return _clubes.where((club) {
      final query = _searchQuery.toLowerCase();
      return club.nombreClub.toLowerCase().contains(query) ||
             club.direccion.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Club'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar club por nombre o dirección...',
                prefixIcon: const Icon(LucideIcons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Contenido
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : _filteredClubes.isEmpty
                        ? _buildEmptyView()
                        : _buildClubesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return RefreshableScrollView(
      onRefresh: _loadClubes,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error al cargar clubes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadClubes,
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return RefreshableScrollView(
      onRefresh: _loadClubes,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.store, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No hay clubes disponibles'
                  : 'No se encontraron clubes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'No hay clubes activos en este momento'
                  : 'Intenta con otro término de búsqueda',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubesList() {
    return RefreshIndicator(
      onRefresh: _loadClubes,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredClubes.length,
        itemBuilder: (context, index) {
          final club = _filteredClubes[index];
          return _buildClubCard(club);
        },
      ),
    );
  }

  Widget _buildClubCard(Club club) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navegar a la pantalla de productos con el clubId
          context.push('/member-orders/new/club-products', extra: {
            'clubId': club.id,
            'clubNombre': club.nombreClub,
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icono del club
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.store,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              
              // Información del club
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.nombreClub,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (club.direccion.isNotEmpty)
                      Row(
                        children: [
                          Icon(LucideIcons.mapPin, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              club.direccion,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (club.horario.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(LucideIcons.clock, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            club.horario,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Icono de flecha
              Icon(
                LucideIcons.chevronRight,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

