import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HostOrdersListScreen extends StatefulWidget {
  const HostOrdersListScreen({super.key});

  @override
  State<HostOrdersListScreen> createState() => _HostOrdersListScreenState();
}

class _HostOrdersListScreenState extends State<HostOrdersListScreen> {
  // Mock Data inicial
  List<Map<String, dynamic>> orders = [
    {
      'id': 'ORD-001',
      'customer': 'María González',
      'items': ['1x Batido Fresa', '1x Té Limón'],
      'total': 40.0,
      'status': 'preparing',
      'time': '09:30',
      'isVip': true
    },
    {
      'id': 'ORD-004',
      'customer': 'Carlos Méndez',
      'items': ['2x Barra Proteína'],
      'total': 24.0,
      'status': 'pending',
      'time': '09:45',
      'isVip': false
    },
     {
      'id': 'ORD-005',
      'customer': 'Ana Martinez',
      'items': ['1x Aloe Vera'],
      'total': 10.0,
      'status': 'ready',
      'time': '09:15',
      'isVip': false
    },
  ];

  String filterStatus = 'all';

  void updateStatus(String id, String newStatus) {
    setState(() {
      orders = orders.map((o) {
        if (o['id'] == id) {
          return {...o, 'status': newStatus};
        }
        return o;
      }).toList();
    });
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
            icon: const Icon(LucideIcons.bell),
            onPressed: () {},
          )
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

                        const SizedBox(height: 12),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                Text('Total: Bs ${order['total']}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
