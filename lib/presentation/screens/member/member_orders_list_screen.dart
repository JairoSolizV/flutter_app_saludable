import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../../data/datasources/remote/order_remote_data_source.dart';
import '../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../domain/entities/club_membership.dart';

class MemberOrdersListScreen extends StatefulWidget {
  const MemberOrdersListScreen({super.key});

  @override
  State<MemberOrdersListScreen> createState() => _MemberOrdersListScreenState();
}

class _MemberOrdersListScreenState extends State<MemberOrdersListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  String? _error;
  ClubMembership? _activeMembership;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrdersFromBackend();
  }

  Future<void> _loadOrdersFromBackend() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _activeMembership = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final membresiaDataSource = Provider.of<MembresiaRemoteDataSource>(context, listen: false);
      final membresias = await membresiaDataSource.getMembresiasPorUsuario(int.parse(user.id));
      
      if (membresias.isEmpty) {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
        return;
      }

      // Obtener pedidos de la primera membresía activa
      final membresia = membresias.first;
      _activeMembership = membresia;

      final orderDataSource = Provider.of<OrderRemoteDataSource>(context, listen: false);
      final ordersData = await orderDataSource.getOrdersBySocio(membresia.id);

      // Mapear pedidos del backend
      final mappedOrders = ordersData.map((order) {
        final dynamic idValue = order['id'];
        final int pedidoId = idValue is int ? idValue : (idValue != null ? int.tryParse(idValue.toString()) ?? 0 : 0);
        
        final dynamic fechaValue = order['fechaPedido'] ?? order['createdAt'];
        final DateTime fecha = fechaValue != null ? DateTime.tryParse(fechaValue.toString()) ?? DateTime.now() : DateTime.now();
        
        final String estado = order['estado']?.toString() ?? 'RECIBIDO';
        final String clubNombre = order['clubNombre']?.toString() ?? 'Club';
        final String tipoConsumo = order['tipoConsumo']?.toString() ?? 'EN_LUGAR';
        final String observaciones = order['observaciones']?.toString() ?? '';
        final dynamic tiempoValue = order['tiempoEstimadoMinutos'];
        final int? tiempoEstimadoMinutos = tiempoValue is int ? tiempoValue : (tiempoValue != null ? int.tryParse(tiempoValue.toString()) : null);
        
        // Obtener items del pedido
        List<Map<String, dynamic>> items = [];
        
        // Opción 1: Si viene como lista de items (estructura correcta del backend)
        if (order['items'] is List) {
          final itemsList = order['items'] as List;
          debugPrint('[DEBUG MEMBER ORDERS] Pedido #$pedidoId - items es List con ${itemsList.length} elementos');
          for (var item in itemsList) {
            if (item is Map) {
              final itemMap = Map<String, dynamic>.from(item);
              debugPrint('[DEBUG MEMBER ORDERS] Item: $itemMap');
              items.add(itemMap);
            }
          }
        } else {
          debugPrint('[DEBUG MEMBER ORDERS] Pedido #$pedidoId - items NO es List, tipo: ${order['items']?.runtimeType}');
          debugPrint('[DEBUG MEMBER ORDERS] Pedido completo: $order');
        }
        
        // Opción 2: Si no hay items pero hay productoNombre y cantidad (compatibilidad con estructura antigua)
        if (items.isEmpty) {
          final String? productoNombre = order['productoNombre']?.toString();
          final dynamic cantidadValue = order['cantidad'];
          final int cantidad = cantidadValue is int ? cantidadValue : (cantidadValue != null ? int.tryParse(cantidadValue.toString()) ?? 1 : 1);
          
          debugPrint('[DEBUG MEMBER ORDERS] Pedido #$pedidoId - Usando compatibilidad, productoNombre: $productoNombre, cantidad: $cantidad');
          
          if (productoNombre != null && productoNombre.isNotEmpty && cantidad > 0) {
            items.add({
              'productoNombre': productoNombre,
              'cantidad': cantidad,
              'nota': observaciones,
            });
          }
        }
        
        debugPrint('[DEBUG MEMBER ORDERS] Pedido #$pedidoId - Total items mapeados: ${items.length}');
        if (items.isNotEmpty) {
          debugPrint('[DEBUG MEMBER ORDERS] Primer item mapeado: ${items.first}');
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
        };
      }).toList();

      setState(() {
        _orders = mappedOrders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filtrado de pedidos según estado
    final activeOrders = _orders.where((o) {
      final estado = o['estado']?.toString().toUpperCase() ?? '';
      return estado != 'ENTREGADO' && estado != 'CANCELADO';
    }).toList();
    
    final historyOrders = _orders.where((o) {
      final estado = o['estado']?.toString().toUpperCase() ?? '';
      return estado == 'ENTREGADO' || estado == 'CANCELADO';
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF7AC142),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF7AC142),
          tabs: const [
            Tab(text: 'Activos'),
            Tab(text: 'Historial'),
          ],
        ), 
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7AC142)))
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _loadOrdersFromBackend,
                  color: const Color(0xFF7AC142),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab Activos
                      _OrdersList(orders: activeOrders),
                      // Tab Historial
                      _OrdersList(orders: historyOrders),
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
        backgroundColor: const Color(0xFF7AC142),
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text('Nuevo Pedido', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const _OrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No hay pedidos en esta sección',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final int pedidoId = order['pedidoId'] as int? ?? order['id'] as int? ?? 0;
        final DateTime fecha = order['fecha'] as DateTime? ?? DateTime.now();
        final String estado = order['estado']?.toString() ?? 'RECIBIDO';
        final String clubNombre = order['clubNombre']?.toString() ?? 'Club';
        final String tipoConsumo = order['tipoConsumo']?.toString() ?? 'EN_LUGAR';
        final String observaciones = order['observaciones']?.toString() ?? '';
        final List<Map<String, dynamic>> items = (order['items'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ?? [];

        // Formatear fecha y hora por separado
        final dateStr = DateFormat('dd/MM/yyyy').format(fecha);
        final timeStr = DateFormat('HH:mm').format(fecha);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      'Pedido #$pedidoId',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    _StatusBadge(status: estado),
                  ],
                ),
                const SizedBox(height: 8),
                if ((estado == 'PREPARANDO' || estado == 'PREPARING') && order['tiempoEstimadoMinutos'] != null)
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
                        const Icon(LucideIcons.clock, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '¡Tu pedido se está preparando! Estará listo en aprox. ${order['tiempoEstimadoMinutos']} minutos.',
                            style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w600),
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
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Fecha
                Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 14, color: Colors.grey[600]),
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
                // Detalle de productos (pedido_items)
                if (items.isEmpty)
                  const Text(
                    'Sin detalle de productos',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Productos:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF333333)),
                      ),
                      const SizedBox(height: 8),
                      ...items.map((item) {
                        final int cantidad = item['cantidad'] as int? ?? 1;
                        // El backend devuelve productoNombre directamente en el item
                        final String productoNombre = item['productoNombre']?.toString() ?? 
                            (item['producto'] is Map
                                ? (item['producto'] as Map)['nombre']?.toString() ?? 'Producto'
                                : 'Producto');
                        final String? nota = item['nota']?.toString();
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• $cantidad x $productoNombre',
                                style: const TextStyle(color: Color(0xFF333333), fontSize: 13),
                              ),
                              if (nota != null && nota.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '($nota)',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                if (observaciones.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Nota: $observaciones',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
                if (tipoConsumo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(LucideIcons.mapPin, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          tipoConsumo == 'PARA_RECOGER' ? 'Para Recoger' : 'Consumir aquí',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    final statusUpper = status.toUpperCase();
    switch (statusUpper) {
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
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
