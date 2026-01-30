import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../providers/product_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/club_membership.dart';
import '../../../data/datasources/remote/membresia_remote_data_source.dart';

class MemberCreateOrderScreen extends StatefulWidget {
  const MemberCreateOrderScreen({super.key});

  @override
  State<MemberCreateOrderScreen> createState() => _MemberCreateOrderScreenState();
}

class _MemberCreateOrderScreenState extends State<MemberCreateOrderScreen> {
  // Mapa de ProductoID -> Cantidad
  final Map<String, int> _cart = {};
  // Mapa de ProductoID -> Nota
  final Map<String, String> _productNotes = {};
  ClubMembership? _membership;
  bool _isLoadingMembership = true;
  String _tipoConsumo = 'EN_LUGAR'; // 'EN_LUGAR' o 'PARA_LLEVAR'
  final TextEditingController _notaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembershipAndProducts();
  }

  @override
  void dispose() {
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _loadMembershipAndProducts() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;
      
      if (user == null) {
        setState(() => _isLoadingMembership = false);
        return;
      }

      // Obtener membresía del socio
      final membresiaDataSource = Provider.of<MembresiaRemoteDataSource>(context, listen: false);
      final membresias = await membresiaDataSource.getMembresiasPorUsuario(int.parse(user.id));
      
      if (membresias.isNotEmpty) {
        final membership = membresias.first;
        setState(() {
          _membership = membership;
          _isLoadingMembership = false;
        });
        
        // Cargar productos disponibles del club
        if (mounted) {
          await Provider.of<ProductProvider>(context, listen: false)
              .loadAvailableProducts(membership.clubId);
        }
      } else {
        setState(() => _isLoadingMembership = false);
      }
    } catch (e) {
      print('Error loading membership: $e');
      setState(() => _isLoadingMembership = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos el ProductProvider existente para mostrar catálogo
    final productProvider = Provider.of<ProductProvider>(context);
    final products = productProvider.products;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    // Calcular total de items (sin precio, solo cantidad)
    int totalItems = 0;
    _cart.forEach((productId, qty) {
      totalItems += qty;
    });

    if (_isLoadingMembership) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nuevo Pedido')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_membership == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nuevo Pedido')),
        body: const Center(
          child: Text('No tienes una membresía activa. Debes ser socio de un club para hacer pedidos.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nuevo Pedido'),
            Text(
              _membership!.clubNombre,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (productProvider.isLoading)
            const LinearProgressIndicator()
          else if (productProvider.error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${productProvider.error}', style: const TextStyle(color: Colors.red)),
            )
          else if (products.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No hay productos disponibles en este momento.'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final qty = _cart[product.id] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 50, 
                      height: 50, 
                      color: Colors.grey[200],
                      child: const Icon(Icons.local_drink), 
                    ),
                    title: Text(product.name),
                    subtitle: product.description.isNotEmpty 
                        ? Text(product.description, maxLines: 2, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (qty > 0)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                if (qty > 1) {
                                  _cart[product.id] = qty - 1;
                                } else {
                                  _cart.remove(product.id);
                                }
                              });
                            },
                          ),
                        if (qty > 0)
                          Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF7AC142)),
                          onPressed: () {
                            setState(() {
                              _cart[product.id] = qty + 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Bottom Cart Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea( // Para evitar notch
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tipo de Consumo
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tipo de consumo:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'EN_LUGAR',
                            label: Text('Consumir aquí'),
                            icon: Icon(Icons.restaurant),
                          ),
                          ButtonSegment(
                            value: 'PARA_LLEVAR',
                            label: Text('Para llevar'),
                            icon: Icon(Icons.shopping_bag),
                          ),
                        ],
                        selected: {_tipoConsumo},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _tipoConsumo = newSelection.first;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Nota general del pedido
                  TextField(
                    controller: _notaController,
                    decoration: const InputDecoration(
                      labelText: 'Notas u observaciones (opcional)',
                      hintText: 'Ej: Sin hielo, extra dulce...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total de items:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('$totalItems', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF7AC142))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: totalItems > 0 ? () async {
                        // Crear Pedido Lógica
                        final orderId = const Uuid().v4();
                        
                        final items = _cart.entries.map((entry) {
                           final product = products.firstWhere((p) => p.id == entry.key);
                           return OrderItem(
                             orderId: orderId,
                             productId: product.id,
                             quantity: entry.value,
                             note: _productNotes[entry.key] ?? '', // Nota específica del producto
                             productName: product.name
                           );
                        }).toList();

                        final userProvider = Provider.of<UserProvider>(context, listen: false);
                        final user = userProvider.currentUser;
                        
                        if (user == null || _membership == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error: Usuario no autenticado o sin membresía'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        final newOrder = OrderEntity(
                          id: orderId,
                          userId: user.id,
                          clubId: _membership!.clubId,
                          membresiaId: _membership!.id,
                          tipoConsumo: _tipoConsumo, // 'EN_LUGAR' o 'PARA_LLEVAR'
                          observaciones: _notaController.text.trim(), // Nota general del pedido
                          status: 'pending',
                          createdAt: DateTime.now(),
                          items: items,
                          isSynced: false
                        );

                        await orderProvider.createOrder(newOrder);
                        
                        if (context.mounted) {
                          context.pop(); // Volver a lista
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pedido creado correctamente'), backgroundColor: Colors.green),
                          );
                        }
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7AC142),
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirmar Pedido', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
