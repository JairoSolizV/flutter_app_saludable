import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/pagination/paged_list_controller.dart';
import '../../../../core/pagination/paged_result.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../../domain/entities/club_membership.dart';
import '../../../providers/user_provider.dart';
import '../pre_socios/host_pre_socios_list_screen.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';

class HostMembersListScreen extends StatefulWidget {
  const HostMembersListScreen({super.key});

  @override
  State<HostMembersListScreen> createState() => _HostMembersListScreenState();
}

class _HostMembersListScreenState extends State<HostMembersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  PagedListController<ClubMembership, int>? _membersController;
  bool _isLoadingClub = true;
  String? _clubError;
  int? _clubId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _initClub();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _membersController?.removeListener(_onMembersChanged);
    _membersController?.dispose();
    super.dispose();
  }

  void _onScroll() {
    final controller = _membersController;
    if (controller == null ||
        !controller.hasNextPage ||
        controller.isLoadingMore) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      controller.loadMore();
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final newQuery = _searchController.text.trim();
      if (newQuery == _query) return;
      setState(() => _query = newQuery);
      _membersController?.loadInitial();
    });
  }

  void _onMembersChanged() {
    if (mounted) setState(() {});
  }

  Future<PagedResult<ClubMembership>> _fetchMembersPage(int page) {
    final clubDataSource =
        Provider.of<ClubRemoteDataSource>(context, listen: false);
    return clubDataSource.getClubMembersPage(
      _clubId!,
      page: page,
      size: 20,
      q: _query.isEmpty ? null : _query,
    );
  }

  void _setupMembersController() {
    _membersController?.removeListener(_onMembersChanged);
    _membersController = PagedListController<ClubMembership, int>(
      fetchPage: _fetchMembersPage,
      idExtractor: (m) => m.id,
    )..addListener(_onMembersChanged);
  }

  Future<void> _handleRefresh() async {
    if (_membersController == null) {
      await _initClub();
    } else {
      await _membersController!.refresh();
    }
  }

  Future<void> _initClub() async {
    if (!mounted) return;
    setState(() {
      _isLoadingClub = true;
      _clubError = null;
    });
    try {
      final user =
          Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user == null) {
        throw Exception("Usuario no autenticado");
      }

      // 1. Obtener el Club del Anfitrión
      final clubDataSource =
          Provider.of<ClubRemoteDataSource>(context, listen: false);
      final club = await clubDataSource.getMyClub();

      if (club == null) {
        throw Exception("No se encontró un club asociado a este anfitrión.");
      }

      _clubId = club.id;
      _setupMembersController();

      if (!mounted) return;
      setState(() => _isLoadingClub = false);
      await _membersController!.loadInitial();
    } catch (e) {
      if (mounted) {
        setState(() {
          _clubError = e.toString().replaceAll("Exception: ", "");
          _isLoadingClub = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Gestión de Socios'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          indicatorColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Socios'),
            Tab(icon: Icon(Icons.person_add), text: 'PreSocios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBody(),
          const HostPreSociosListScreen(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final membersController = _membersController;
    final bool isInitialLoading =
        _isLoadingClub || (membersController?.isInitialLoading ?? false);
    final String? topLevelError =
        _clubError ?? membersController?.initialError?.toString();

    if (isInitialLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    if (topLevelError != null) {
      return RefreshableScrollView(
        onRefresh: _handleRefresh,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              topLevelError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleRefresh,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white),
              child: const Text("Reintentar"),
            )
          ],
        ),
      );
    }

    final members = membersController?.items ?? const <ClubMembership>[];
    final totalElements = membersController?.totalElements ?? members.length;

    if (members.isEmpty) {
      return RefreshableScrollView(
        onRefresh: _handleRefresh,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _query.isEmpty
                  ? 'No hay socios registrados aún.'
                  : 'No se encontraron socios',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppTheme.primaryColor,
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
                    const Icon(LucideIcons.users,
                        color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Total de Socios: $totalElements',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalElements',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
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
                suffixIcon: _searchController.text.isNotEmpty
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
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: members.length + 1,
              itemBuilder: (context, index) {
                if (index == members.length) {
                  return _buildListFooter();
                }
                final member = members[index];
                return _buildMemberCard(member);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListFooter() {
    final controller = _membersController;
    if (controller == null) return const SizedBox.shrink();
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton(
            onPressed: controller.loadMore,
            child: const Text('Reintentar cargar más'),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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
        onTap: () => context.push(
          '/host/members/${member.id}',
          extra: {'memberName': member.usuarioNombre},
        ),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(
              member.usuarioNombre.isNotEmpty
                  ? member.usuarioNombre[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[50], // Color suave para nivel
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green[100]!),
                    ),
                    child: Text(
                      member.nivelNombre,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[800],
                          fontWeight: FontWeight.w500),
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
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
