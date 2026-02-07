import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../data/datasources/remote/order_remote_data_source.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';
import '../../providers/user_provider.dart';

class HostOrdersListScreen extends StatefulWidget {
  const HostOrdersListScreen({super.key});

  @override
  State<HostOrdersListScreen> createState() => _HostOrdersListScreenState();
}

class _HostOrdersListScreenState extends State<HostOrdersListScreen> {
  List<Map<String, dynamic>> orders = [];
  String filterStatus = 'all';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!mounted) return;
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;
      
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener el club del anfitrión usando GET /api/clubes/mio
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      debugPrint('[DEBUG HOST] Obteniendo club del anfitrión autenticado...');
      
      Club? club;
      try {
        club = await clubDataSource.getMyClub();
      } catch (e) {
        debugPrint('[DEBUG HOST] ERROR al obtener club: $e');
        // Si el error es 404 o contiene "No se encontró", es porque el usuario no tiene un club asignado
        if (e.toString().contains('No se encontró') || e.toString().contains('404')) {
          throw Exception('No tienes un club asignado como anfitrión. Contacta al administrador para que te asigne un club.');
        }
        rethrow;
      }
      
      if (club == null) {
        debugPrint('[DEBUG HOST] ERROR: No se encontró el club del anfitrión');
        throw Exception('No se encontró el club del anfitrión. Verifica que tengas un club asignado.');
      }

      debugPrint('[DEBUG HOST] Club encontrado - ID: ${club.id}, Nombre: ${club.nombreClub}');
      debugPrint('[DEBUG HOST] ClubId anfitrión: ${club.id}');
      debugPrint('[DEBUG HOST] Buscando pedidos para clubId: ${club.id}');

      // Obtener pedidos del club
      final orderDataSource = Provider.of<OrderRemoteDataSource>(context, listen: false);
      
      // DEBUG: Obtener todos los pedidos para verificar si hay pedidos en la BD
      try {
        final allOrders = await orderDataSource.getAllOrders();
        debugPrint('[DEBUG HOST] Total de pedidos en la BD (todos los clubes): ${allOrders.length}');
        if (allOrders.isNotEmpty) {
          debugPrint('[DEBUG HOST] Verificando clubId de los pedidos existentes...');
          for (var order in allOrders) {
            int? orderClubId;
            if (order.containsKey('clubId')) {
              orderClubId = order['clubId'] as int?;
            } else if (order.containsKey('membresia')) {
              final membresia = order['membresia'];
              if (membresia is Map) {
                orderClubId = membresia['clubId'] as int?;
              }
            }
            debugPrint('[DEBUG HOST]   Pedido ID: ${order['id']}, clubId: $orderClubId (buscamos: ${club.id})');
          }
        }
      } catch (e) {
        debugPrint('[DEBUG HOST] No se pudo obtener todos los pedidos (puede que el endpoint no exista): $e');
      }
      
      final ordersData = await orderDataSource.getOrdersByClub(club.id);
      
      debugPrint('[DEBUG HOST] Después de getOrdersByClub - Pedidos recibidos: ${ordersData.length}');
      
      debugPrint('[DEBUG HOST] Datos recibidos del backend: ${ordersData.length} pedidos');
      if (ordersData.isEmpty) {
        debugPrint('[DEBUG HOST] No hay pedidos en la respuesta del backend');
        if (mounted) {
          setState(() {
            orders = [];
            _isLoading = false;
          });
        }
        return;
      }
      
      debugPrint('[DEBUG HOST] Ejemplo de estructura del primer pedido:');
      debugPrint('[DEBUG HOST] Keys: ${ordersData.first.keys.toList()}');
      debugPrint('[DEBUG HOST] Primer pedido: ${ordersData.first}');
      
      // El backend devuelve pedidos individuales (uno por producto)
      // Agrupar por membresiaId y fechaPedido para mostrar pedidos completos
      final Map<String, List<Map<String, dynamic>>> groupedOrders = {};
      
      for (var order in ordersData) {
        try {
          // Extraer información del pedido según estructura real del backend
          final dynamic idValue = order['id'];
          final int pedidoId = idValue is int ? idValue : (idValue != null ? int.tryParse(idValue.toString()) ?? 0 : 0);
          
          if (pedidoId == 0) {
            debugPrint('[DEBUG HOST] WARNING: Pedido sin ID válido, saltando: $order');
            continue;
          }
          
          final String estado = _mapBackendStatusToUI(order['estado'] ?? order['status'] ?? 'RECIBIDO');
          final dynamic fechaValue = order['fechaPedido'] ?? order['fechaPedido'] ?? order['createdAt'] ?? DateTime.now().toIso8601String();
          final String fechaPedido = fechaValue.toString();
          final DateTime fecha = DateTime.tryParse(fechaPedido) ?? DateTime.now();
          final String time = DateFormat('HH:mm').format(fecha);
          
          // Información del socio/cliente - el backend puede devolver esto de diferentes formas
          final dynamic membresiaData = order['membresia'] ?? order['membresiaId'];
          final Map<String, dynamic> membresia = membresiaData is Map ? membresiaData as Map<String, dynamic> : {};
          final dynamic membresiaIdValue = membresia['id'] ?? order['membresiaId'];
          final int membresiaId = membresiaIdValue is int ? membresiaIdValue : (membresiaIdValue != null ? int.tryParse(membresiaIdValue.toString()) ?? pedidoId : pedidoId);
          
          final dynamic usuarioData = membresia['usuario'] ?? order['socio'] ?? order['usuario'];
          final Map<String, dynamic> socio = usuarioData is Map ? usuarioData as Map<String, dynamic> : {};
          
          String customerName = 'Cliente $pedidoId';
          if (socio.isNotEmpty) {
            final String? nombre = socio['nombre']?.toString();
            final String? apellido = socio['apellido']?.toString();
            final String? usuarioNombre = socio['usuarioNombre']?.toString();
            
            if (nombre != null && apellido != null) {
              customerName = '$nombre $apellido';
            } else if (nombre != null) {
              customerName = nombre;
            } else if (usuarioNombre != null) {
              customerName = usuarioNombre;
            }
          }
          
          // Información del producto
          // El backend devuelve productoNombre directamente como string, no como objeto
          final String productoNombre = order['productoNombre']?.toString() ?? 
                                      (order['producto'] is Map ? (order['producto'] as Map)['nombre']?.toString() : null) ?? 
                                      'Producto';
          final dynamic cantidadValue = order['cantidad'];
          final int cantidad = cantidadValue is int ? cantidadValue : (cantidadValue != null ? int.tryParse(cantidadValue.toString()) ?? 1 : 1);
          
          // Verificar si es VIP (puede venir del nivel de la membresía)
          final dynamic nivelData = membresia['nivel'];
          final Map<String, dynamic> nivel = nivelData is Map ? nivelData as Map<String, dynamic> : {};
          final String nivelNombre = nivel['nombre']?.toString() ?? nivel['nivelNombre']?.toString() ?? '';
          final bool isVip = nivelNombre.toUpperCase().contains('VIP') || nivelNombre.toUpperCase().contains('PREMIUM');
          
          // Crear clave única para agrupar pedidos del mismo socio en la misma fecha
          final String fechaKey = DateFormat('yyyy-MM-dd HH:mm').format(fecha);
          final String groupKey = '${membresiaId}_$fechaKey';
          
          if (!groupedOrders.containsKey(groupKey)) {
            groupedOrders[groupKey] = [];
          }
          
          groupedOrders[groupKey]!.add({
            'pedidoId': pedidoId,
            'productoNombre': productoNombre,
            'cantidad': cantidad,
            'estado': estado,
            'tipoConsumo': order['tipoConsumo']?.toString() ?? 'EN_LUGAR',
            'observaciones': order['observaciones']?.toString() ?? '',
            'customerName': customerName,
            'isVip': isVip,
            'time': time,
          });
        } catch (e, stackTrace) {
          debugPrint('[DEBUG HOST] Error procesando pedido: $e');
          debugPrint('[DEBUG HOST] Stack trace: $stackTrace');
          debugPrint('[DEBUG HOST] Pedido que causó error: $order');
          continue; // Continuar con el siguiente pedido
        }
      }
      
      debugPrint('[DEBUG HOST] Pedidos agrupados: ${groupedOrders.length} grupos');
      
      // Convertir grupos a formato de UI
      final mappedOrders = groupedOrders.entries.map((entry) {
        final items = entry.value;
        final firstItem = items.first;
        final int pedidoId = firstItem['pedidoId'] as int;
        final String estado = firstItem['estado'] as String;
        final String time = firstItem['time'] as String;
        final String customerName = firstItem['customerName'] as String;
        final bool isVip = firstItem['isVip'] as bool;
        
        // Construir lista de items agrupando productos iguales y sumando cantidades
        final Map<String, int> productosAgrupados = {};
        for (var item in items) {
          final int cantidad = item['cantidad'] as int;
          final String productoNombre = item['productoNombre'] as String;
          productosAgrupados[productoNombre] = (productosAgrupados[productoNombre] ?? 0) + cantidad;
        }
        
        final List<String> itemsList = productosAgrupados.entries.map<String>((entry) {
          return '${entry.value} x ${entry.key}';
        }).toList();
        
        return {
          'id': pedidoId.toString(),
          'pedidoId': pedidoId,
          'customer': customerName,
          'items': itemsList,
          'status': estado,
          'time': time,
          'isVip': isVip,
          'tipoConsumo': firstItem['tipoConsumo'] ?? 'EN_LUGAR',
          'observaciones': firstItem['observaciones'] ?? '',
        };
      }).toList();
      
      debugPrint('[DEBUG HOST] Pedidos mapeados para UI: ${mappedOrders.length}');

      if (mounted) {
        setState(() {
          orders = mappedOrders;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[DEBUG HOST] Error completo en _loadOrders: $e');
      debugPrint('[DEBUG HOST] Stack trace: $stackTrace');
      
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        if (errorMessage.contains('Error obteniendo pedidos')) {
          errorMessage = 'No se pudieron cargar los pedidos. Verifica tu conexión y que el club tenga pedidos.';
        }
        
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  String _mapBackendStatusToUI(String backendStatus) {
    // Mapear estados del backend a estados de la UI
    switch (backendStatus.toUpperCase()) {
      case 'RECIBIDO':
      case 'PENDING':
        return 'pending';
      case 'PREPARANDO':
      case 'PREPARING':
        return 'preparing';
      case 'LISTO':
      case 'READY':
        return 'ready';
      case 'ENTREGADO':
      case 'COMPLETED':
        return 'completed';
      default:
        return 'pending';
    }
  }

  String _mapUIToBackendStatus(String uiStatus) {
    // Mapear estados de la UI a estados del backend
    switch (uiStatus) {
      case 'pending':
        return 'RECIBIDO';
      case 'preparing':
        return 'PREPARANDO';
      case 'ready':
        return 'LISTO';
      case 'completed':
        return 'ENTREGADO';
      default:
        return 'RECIBIDO';
    }
  }

  Future<void> updateStatus(String id, String newStatus) async {
    try {
      // Encontrar el pedido para obtener el pedidoId numérico
      final order = orders.firstWhere((o) => o['id'] == id);
      final int pedidoId = order['pedidoId'] ?? int.parse(id);
      
      // Actualizar en el backend
      final orderDataSource = Provider.of<OrderRemoteDataSource>(context, listen: false);
      final backendStatus = _mapUIToBackendStatus(newStatus);
      await orderDataSource.updateOrderStatus(pedidoId, backendStatus);
      
      // Actualizar localmente
      if (mounted) {
    setState(() {
      orders = orders.map((o) {
        if (o['id'] == id) {
          return {...o, 'status': newStatus};
        }
        return o;
      }).toList();
    });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar estado: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = filterStatus == 'all' 
        ? orders 
        : orders.where((o) => o['status'] == filterStatus).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos Recibidos'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadOrders,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                    label: 'Todos', 
                    isSelected: filterStatus == 'all', 
                    onTap: () => setState(() => filterStatus = 'all')
                ),
                _FilterChip(
                    label: 'Pendientes', 
                    isSelected: filterStatus == 'pending', 
                    color: Colors.red,
                    onTap: () => setState(() => filterStatus = 'pending')
                ),
                _FilterChip(
                    label: 'Preparando', 
                    isSelected: filterStatus == 'preparing', 
                    color: Colors.orange,
                    onTap: () => setState(() => filterStatus = 'preparing')
                ),
                _FilterChip(
                    label: 'Listos', 
                    isSelected: filterStatus == 'ready', 
                    color: Colors.green,
                    onTap: () => setState(() => filterStatus = 'ready')
                ),
              ],
            ),
          ),

          // Lista de Pedidos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.alertCircle, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadOrders,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.package, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'No hay pedidos para este club',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Los pedidos aparecerán aquí cuando los socios realicen pedidos',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: const Color(0xFF7AC142), width: 4)),
                         borderRadius: BorderRadius.circular(16)
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                                children: [
                                    Text(order['id'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(width: 8),
                                    if (order['isVip'])
                                        Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.yellow[100], borderRadius: BorderRadius.circular(10)),
                                            child: const Text('VIP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                        )
                                ],
                            ),
                            _StatusBadge(status: order['status']),
                          ],
                        ),
                        Text('${order['customer']} • ${order['time']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        
                        const SizedBox(height: 12),
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: (order['items'] as List<String>).map((item) => Text('• $item')).toList(),
                            ),
                        ),

                        if (order['observaciones'] != null && order['observaciones'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Nota: ${order['observaciones']}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                            ),
                          ),
                        if (order['tipoConsumo'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(LucideIcons.mapPin, size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  order['tipoConsumo'] == 'PARA_LLEVAR' ? 'Para llevar' : 'Consumir aquí',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                const SizedBox(), // Ya no mostramos total porque no viene del backend
                                Row(
                                    children: [
                                        if (order['status'] == 'pending')
                                            ElevatedButton(
                                                onPressed: () => updateStatus(order['id'], 'preparing'),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                                child: const Text('Preparar', style: TextStyle(color: Colors.white)),
                                            ),
                                        if (order['status'] == 'preparing')
                                            ElevatedButton(
                                                onPressed: () => updateStatus(order['id'], 'ready'),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                                child: const Text('Listo', style: TextStyle(color: Colors.white)),
                                            ),
                                        if (order['status'] == 'ready')
                                            ElevatedButton(
                                                onPressed: () => updateStatus(order['id'], 'completed'),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                                                child: const Text('Entregar', style: TextStyle(color: Colors.white)),
                                            ),
                                    ],
                                )
                            ],
                        )
                      ],
                    ),
                  ),
                );
              },
                            ),
            ),
          )
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
    final String label;
    final bool isSelected;
    final VoidCallback onTap;
    final Color? color;

    const _FilterChip({required this.label, required this.isSelected, required this.onTap, this.color});

    @override
    Widget build(BuildContext context) {
        final activeColor = color ?? const Color(0xFF333333);
        return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => onTap(),
                selectedColor: activeColor,
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                backgroundColor: Colors.white,
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

    switch (status) {
      case 'pending': color = Colors.red; text = 'Pendiente'; break;
      case 'preparing': color = Colors.orange; text = 'Preparando'; break;
      case 'ready': color = Colors.green; text = 'Listo'; break;
      case 'completed': color = Colors.grey; text = 'Entregado'; break;
      default: color = Colors.grey; text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
