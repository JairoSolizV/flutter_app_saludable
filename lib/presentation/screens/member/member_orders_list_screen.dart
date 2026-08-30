import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../../core/pagination/paged_list_controller.dart';
import '../../../core/pagination/paged_result.dart';
import '../../../data/datasources/remote/order_remote_data_source.dart';
import '../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../domain/entities/club_membership.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/repositories/order_repository.dart';
import 'package:flutter_app_saludable/core/orders/order_offline_messages.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/presentation/widgets/order_history_lines.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';
import 'member_local_order_mapper.dart';

// Pedidos offline pendientes se mezclan en Activos leyendo SQLite local.
class MemberOrdersListScreen extends StatefulWidget {
  const MemberOrdersListScreen({super.key});

  @override
  State<MemberOrdersListScreen> createState() => _MemberOrdersListScreenState();
}

class _MemberOrdersListScreenState extends State<MemberOrdersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _activeScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  PagedListController<Map<String, dynamic>, int>? _ordersController;

  bool _isLoadingMembresia = true;
  String? _membresiaError;
  ClubMembership? _activeMembership;
  List<OrderEntity> _localPendingOrders = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _activeScrollController
        .addListener(() => _maybeLoadMore(_activeScrollController));
    _historyScrollController
        .addListener(() => _maybeLoadMore(_historyScrollController));
    _initMembresia();
  }

  void _maybeLoadMore(ScrollController scrollController) {
    final controller = _ordersController;
    if (controller == null ||
        !controller.hasNextPage ||
        controller.isLoadingMore) return;
    if (!scrollController.hasClients) return;
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      controller.loadMore();
    }
  }

  int _orderId(Map<String, dynamic> order) {
    final dynamic idValue = order['id'];
    if (idValue is int) return idValue;
    return int.tryParse(idValue?.toString() ?? '') ?? 0;
  }

  void _onOrdersChanged() {
    if (mounted) setState(() {});
  }

  Future<PagedResult<Map<String, dynamic>>> _fetchOrdersPage(
      int membresiaId, int page) {
    final orderDataSource =
        Provider.of<OrderRemoteDataSource>(context, listen: false);
    return orderDataSource.getOrdersBySocioPage(membresiaId,
        page: page, size: 20);
  }

  void _setupOrdersController(int membresiaId) {
    _ordersController?.removeListener(_onOrdersChanged);
    _ordersController = PagedListController<Map<String, dynamic>, int>(
      fetchPage: (page) => _fetchOrdersPage(membresiaId, page),
      idExtractor: _orderId,
    )..addListener(_onOrdersChanged);
  }

  Future<void> _handleRefresh() async {
    final user =
        Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user != null) {
      await _loadLocalPendingOrders(user.id);
    }
    if (_ordersController == null) {
      await _initMembresia();
    } else {
      await _ordersController!.refresh();
    }
  }

  Future<void> _loadLocalPendingOrders(String userId) async {
    final repo = Provider.of<OrderRepository>(context, listen: false);
    final pending = await repo.getUnsyncedOrdersForUser(userId);
    if (!mounted) return;
    setState(() => _localPendingOrders = pending);
  }

  List<Map<String, dynamic>> _mapLocalPendingOrders() {
    final clubName = _activeMembership?.clubNombre;
    return _localPendingOrders
        .map(
          (o) => MemberLocalOrderMapper.toUiMap(
            o,
            clubNombreFallback: clubName,
          ),
        )
        .toList();
  }

  bool get _hasLocalPending => _localPendingOrders.isNotEmpty;

  Future<void> _initMembresia() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMembresia = true;
      _membresiaError = null;
      _activeMembership = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      await _loadLocalPendingOrders(user.id);

      final membresiaDataSource =
          Provider.of<MembresiaRemoteDataSource>(context, listen: false);
      final membresias =
          await membresiaDataSource.getMembresiasPorUsuario(int.parse(user.id));

      if (membresias.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoadingMembresia = false);
        return;
      }

      // Obtener pedidos de la primera membresía activa
      final membresia = membresias.first;
      _activeMembership = membresia;
      _setupOrdersController(membresia.id);

      if (!mounted) return;
      setState(() => _isLoadingMembresia = false);
      await _ordersController!.loadInitial();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _membresiaError = e.toString().replaceAll('Exception: ', '');
        _isLoadingMembresia = false;
      });
    }
  }

  /// Mapea un pedido crudo del backend al formato usado por la UI.
  /// Función pura: no muta estado ni hace I/O.
  Map<String, dynamic> _mapOrder(Map<String, dynamic> order) {
    final dynamic idValue = order['id'];
    final int pedidoId = idValue is int
        ? idValue
        : (idValue != null ? int.tryParse(idValue.toString()) ?? 0 : 0);

    final dynamic fechaValue = order['fechaPedido'] ?? order['createdAt'];
    final DateTime fecha = fechaValue != null
        ? DateTime.tryParse(fechaValue.toString()) ?? DateTime.now()
        : DateTime.now();

    final String estado = order['estado']?.toString() ?? 'RECIBIDO';
    final String clubNombre = order['clubNombre']?.toString() ?? 'Club';
    final String tipoConsumo = order['tipoConsumo']?.toString() ?? 'EN_LUGAR';
    final String observaciones = order['observaciones']?.toString() ?? '';
    final dynamic tiempoValue =
        order['tiempoEstimadoMinutos'] ?? order['tiempo_estimado_minutos'];
    final int? tiempoEstimadoMinutos = tiempoValue is int
        ? tiempoValue
        : (tiempoValue != null ? int.tryParse(tiempoValue.toString()) : null);

    // Obtener items del pedido
    List<Map<String, dynamic>> items = [];

    // Opción 1: Si viene como lista de items (estructura correcta del backend)
    if (order['items'] is List) {
      final itemsList = order['items'] as List;
      for (var item in itemsList) {
        if (item is Map) {
          items.add(Map<String, dynamic>.from(item));
        }
      }
    }

    // Opción 2: Si no hay items pero hay productoNombre y cantidad (compatibilidad con estructura antigua)
    if (items.isEmpty) {
      final String? productoNombre = order['productoNombre']?.toString();
      final dynamic cantidadValue = order['cantidad'];
      final int cantidad = cantidadValue is int
          ? cantidadValue
          : (cantidadValue != null
              ? int.tryParse(cantidadValue.toString()) ?? 1
              : 1);

      if (productoNombre != null && productoNombre.isNotEmpty && cantidad > 0) {
        items.add({
          'productoNombre': productoNombre,
          'cantidad': cantidad,
          'nota': observaciones,
        });
      }
    }

    return {
      'id': pedidoId,
      'pedidoId': pedidoId,
      'fecha': fecha,
      'estado': estado,
      'clubNombre': clubNombre,
      'tipoConsumo': tipoConsumo,
      'observaciones': observaciones,
      'tiempoEstimadoMinutos': tiempoEstimadoMinutos,
      'items': items,
      if (order['combos'] is List) 'combos': order['combos'],
    };
  }

  Widget? _buildFooter() {
    final controller = _ordersController;
    if (controller == null) return null;
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
    return null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activeScrollController.dispose();
    _historyScrollController.dispose();
    _ordersController?.removeListener(_onOrdersChanged);
    _ordersController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawOrders =
        _ordersController?.items ?? const <Map<String, dynamic>>[];
    final mappedOrders = rawOrders.map(_mapOrder).toList();
    final localActive = _mapLocalPendingOrders();

    // Filtrado local de pedidos según estado (partición del mismo feed
    // paginado; el backend no distingue Activos/Historial).
    final remoteActive = mappedOrders.where((o) {
      final estado = o['estado']?.toString().toUpperCase() ?? '';
      return estado != 'ENTREGADO' && estado != 'CANCELADO';
    }).toList();

    // Pending local primero; IDs distintos (UUID vs int backend) evitan duplicados.
    final activeOrders = [...localActive, ...remoteActive];

    final historyOrders = mappedOrders.where((o) {
      final estado = o['estado']?.toString().toUpperCase() ?? '';
      return estado == 'ENTREGADO' || estado == 'CANCELADO';
    }).toList();

    final bool isInitialLoading = _isLoadingMembresia ||
        ((_ordersController?.isInitialLoading ?? false) && !_hasLocalPending);

    final remoteError = _ordersController?.initialError;
    final bool showOfflineEmpty = _membresiaError == null &&
        remoteError != null &&
        !_hasLocalPending &&
        OrderOfflineMessages.isLikelyNetworkError(remoteError);

    final String? otherError = _membresiaError ??
        (remoteError != null &&
                !_hasLocalPending &&
                !OrderOfflineMessages.isLikelyNetworkError(remoteError)
            ? OrderOfflineMessages.friendlyLoadError(remoteError)
            : null);

    final bool showOfflineRemoteHint =
        remoteError != null && _hasLocalPending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Activos'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: isInitialLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : showOfflineEmpty
              ? _OfflineEmptyState(onRetry: _handleRefresh)
              : otherError != null
                  ? RefreshableScrollView(
                      onRefresh: _handleRefresh,
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          otherError.startsWith('Error:')
                              ? otherError
                              : 'Error: $otherError',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    )
              : RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: AppTheme.primaryColor,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _OrdersList(
                        orders: activeOrders,
                        scrollController: _activeScrollController,
                        footer: _buildFooter(),
                        offlineBanner: showOfflineRemoteHint
                            ? OrderOfflineMessages.localPendingBanner
                            : null,
                      ),
                      _OrdersList(
                        orders: historyOrders,
                        scrollController: _historyScrollController,
                        footer: _buildFooter(),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_activeMembership != null) {
            context.push('/member-orders/new/club-products', extra: {
              'clubId': _activeMembership!.clubId,
              'clubNombre': _activeMembership!.clubNombre,
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No tienes un club asociado')),
            );
          }
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label:
            const Text('Nuevo Pedido', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _OfflineEmptyState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _OfflineEmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return RefreshableScrollView(
      onRefresh: onRetry,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.wifiOff, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              OrderOfflineMessages.offlineEmptyTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              OrderOfflineMessages.offlineEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final ScrollController? scrollController;
  final Widget? footer;
  final String? offlineBanner;

  const _OrdersList({
    required this.orders,
    this.scrollController,
    this.footer,
    this.offlineBanner,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      // Scrolleable para que el RefreshIndicator ancestro capture el gesto
      // de "deslizar para actualizar" incluso con la lista vacía.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No hay pedidos en esta sección',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: orders.length +
          (offlineBanner != null ? 1 : 0) +
          (footer != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (offlineBanner != null && index == 0) {
          return _OfflineBanner(message: offlineBanner!);
        }
        final orderIndex = index - (offlineBanner != null ? 1 : 0);
        if (orderIndex == orders.length) return footer!;
        final order = orders[orderIndex];
        final bool isLocalPending = order['isLocalPending'] == true;
        final dynamic pedidoIdRaw =
            order['pedidoId'] ?? order['id'] ?? order['localId'];
        final DateTime fecha = order['fecha'] as DateTime? ?? DateTime.now();
        final String estado = order['estado']?.toString() ?? 'RECIBIDO';
        final String clubNombre = order['clubNombre']?.toString() ?? 'Club';
        final String tipoConsumo =
            order['tipoConsumo']?.toString() ?? 'EN_LUGAR';
        final String observaciones = order['observaciones']?.toString() ?? '';
        final List<Map<String, dynamic>> items =
            (order['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                [];

        // Formatear fecha y hora por separado
        final dateStr = DateFormat('dd/MM/yyyy').format(fecha);
        final timeStr = DateFormat('HH:mm').format(fecha);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera: Pedido #ID, Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isLocalPending
                          ? 'Pedido pendiente de envío'
                          : 'Pedido #$pedidoIdRaw',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    _StatusBadge(status: estado),
                  ],
                ),
                if (isLocalPending) ...[
                  const SizedBox(height: 8),
                  _OfflineBanner(
                    message: OrderOfflineMessages.localPendingBanner,
                    compact: true,
                  ),
                ],
                const SizedBox(height: 8),
                if ((estado == 'PREPARANDO' || estado == 'PREPARING') &&
                    order['tiempoEstimadoMinutos'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.clock,
                            size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '¡Tu pedido se está preparando! Estará listo en aprox. ${order['tiempoEstimadoMinutos']} minutos.',
                            style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Club
                Row(
                  children: [
                    Icon(LucideIcons.store, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      clubNombre,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Fecha
                Row(
                  children: [
                    Icon(LucideIcons.calendar,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Hora
                Row(
                  children: [
                    Icon(LucideIcons.clock, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Productos:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                OrderHistoryLines(order: order),
                if (observaciones.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Nota: $observaciones',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                if (tipoConsumo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(LucideIcons.mapPin,
                            size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          tipoConsumo == 'PARA_RECOGER'
                              ? 'Para Recoger'
                              : 'Consumir aquí',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final String message;
  final bool compact;

  const _OfflineBanner({required this.message, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 0 : 12),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.wifiOff,
            size: compact ? 16 : 18,
            color: Colors.amber.shade900,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              compact ? '[Sin conexión] $message' : message,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    final statusUpper = status.toUpperCase();
    switch (statusUpper) {
      case 'LOCAL_PENDING':
        color = Colors.amber;
        text = 'Pendiente de envío';
        break;
      case 'RECIBIDO':
      case 'PENDING':
        color = Colors.orange;
        text = 'Recibido';
        break;
      case 'PREPARANDO':
      case 'PREPARING':
        color = Colors.blue;
        text = 'Preparando';
        break;
      case 'LISTO':
      case 'READY':
        color = Colors.green;
        text = 'Listo';
        break;
      case 'ENTREGADO':
      case 'COMPLETED':
        color = Colors.grey;
        text = 'Entregado';
        break;
      case 'CANCELADO':
      case 'CANCELLED':
        color = Colors.red;
        text = 'Cancelado';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
