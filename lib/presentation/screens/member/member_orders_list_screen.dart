import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart'; // Provider
import '../../providers/order_provider.dart'; // OrderProvider
import '../../providers/user_provider.dart';

class MemberOrdersListScreen extends StatefulWidget {
  const MemberOrdersListScreen({super.key});

  @override
  State<MemberOrdersListScreen> createState() => _MemberOrdersListScreenState();
}

class _MemberOrdersListScreenState extends State<MemberOrdersListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Cargar pedidos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user != null) {
        Provider.of<OrderProvider>(context, listen: false).loadOrders(user.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        final orders = orderProvider.orders;
        
        // Filtrado simple en memoria para tabs
        final activeOrders = orders.where((o) => o.status != 'completed' && o.status != 'cancelled').toList();
        final historyOrders = orders.where((o) => o.status == 'completed' || o.status == 'cancelled').toList();

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
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab Activos
              _OrdersList(orders: activeOrders),
              // Tab Historial
              _OrdersList(orders: historyOrders),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              context.push('/member-orders/new'); 
            },
            backgroundColor: const Color(0xFF7AC142),
            icon: const Icon(LucideIcons.plus, color: Colors.white),
            label: const Text('Nuevo Pedido', style: TextStyle(color: Colors.white)),
          ),
        );
      },
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<dynamic> orders; // Dynamic para aceptar OrderEntity

  const _OrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(child: Text('No hay pedidos en esta sección'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        // Formateo simple de fecha
        final dateStr = "${order.createdAt.day}/${order.createdAt.month} ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}";
        
        // Construir string de items
        final itemsStr = order.items.map((i) => "${i.quantity}x ${i.productName}").join(", ");

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.id.substring(0, 8), // ID corto visualmente
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Divider(height: 24),
                Text(
                  itemsStr.isEmpty ? 'Sin detalle' : itemsStr,
                  style: const TextStyle(color: Color(0xFF333333)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Total: Bs ${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                )
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

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Pendiente';
        break;
      case 'preparing': // En preparación
        color = Colors.blue;
        text = 'Preparando';
        break;
      case 'ready':
        color = Colors.green;
        text = 'Listo';
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
