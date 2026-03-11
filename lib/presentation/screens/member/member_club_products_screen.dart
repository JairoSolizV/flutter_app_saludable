import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../providers/product_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/club_membership.dart';
import '../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../widgets/product_image.dart';

class MemberClubProductsScreen extends StatefulWidget {
  final int clubId;
  final String clubNombre;

  const MemberClubProductsScreen({
    super.key,
    required this.clubId,
    required this.clubNombre,
  });

  @override
  State<MemberClubProductsScreen> createState() => _MemberClubProductsScreenState();
}

class _MemberClubProductsScreenState extends State<MemberClubProductsScreen> {
  // Mapa de ProductoID -> Cantidad
  final Map<String, int> _cart = {};
  // Mapa de ProductoID -> Nota
  final Map<String, String> _productNotes = {};
  ClubMembership? _membership;
  bool _isLoadingMembership = true;
  bool _isCreatingOrder = false;
  String _tipoConsumo = 'EN_LUGAR'; // 'EN_LUGAR' o 'PARA_RECOGER'
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
        setState(() {
          _membership = membresias.first;
          _isLoadingMembership = false;
        });
        
        // Cargar productos disponibles del club seleccionado
        if (mounted) {
          await Provider.of<ProductProvider>(context, listen: false)
              .loadAvailableProducts(widget.clubId);
        }
      } else {
        setState(() => _isLoadingMembership = false);
      }
    } catch (e) {
      debugPrint('Error loading membership: $e');
      setState(() => _isLoadingMembership = false);
    }
  }

  void _updateQuantity(String productId, int delta) {
    setState(() {
      final currentQty = _cart[productId] ?? 0;
      final newQty = (currentQty + delta).clamp(0, 99);
      if (newQty > 0) {
        _cart[productId] = newQty;
      } else {
        _cart.remove(productId);
        _productNotes.remove(productId);
      }
    });
  }

  void _showNoteDialog(String productId, String productName) {
    final currentNote = _productNotes[productId] ?? '';
    final controller = TextEditingController(text: currentNote);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nota para $productName'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ej: Sin azúcar, extra hielo...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (controller.text.trim().isEmpty) {
                  _productNotes.remove(productId);
                } else {
                  _productNotes[productId] = controller.text.trim();
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  int get _totalItems {
    return _cart.values.fold(0, (sum, qty) => sum + qty);
  }

  Future<void> _createOrder() async {
    // Bloquear el botón inmediatamente para evitar doble clic
    if (_isCreatingOrder) {
      return; // Ya hay un pedido en proceso
    }

    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un producto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_membership == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes una membresía activa'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Establecer el estado de carga inmediatamente
    setState(() => _isCreatingOrder = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser!;
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final orderId = const Uuid().v4();
      
      // Crear items del pedido
      final List<OrderItem> items = [];
      for (var entry in _cart.entries) {
        items.add(OrderItem(
          orderId: orderId,
          productId: entry.key,
          quantity: entry.value,
          note: _productNotes[entry.key] ?? '',
        ));
      }
      
      debugPrint('[DEBUG CREATE] Creando pedido con:');
      debugPrint('[DEBUG CREATE]   clubId seleccionado: ${widget.clubId}');
      debugPrint('[DEBUG CREATE]   clubNombre: ${widget.clubNombre}');
      debugPrint('[DEBUG CREATE]   membresiaId: ${_membership!.id}');
      debugPrint('[DEBUG CREATE]   items: ${items.length}');
      debugPrint('[DEBUG CREATE]   tipoConsumo: $_tipoConsumo');

      final newOrder = OrderEntity(
        id: orderId,
        userId: user.id,
        clubId: widget.clubId, // Usar el clubId seleccionado
        membresiaId: _membership!.id,
        tipoConsumo: _tipoConsumo,
        observaciones: _notaController.text.trim(),
        status: 'pending',
        createdAt: DateTime.now(),
        items: items,
        isSynced: false,
      );

      debugPrint('[DEBUG CREATE] OrderEntity creado - clubId: ${newOrder.clubId}, membresiaId: ${newOrder.membresiaId}');
      
      await orderProvider.createOrder(newOrder);
      debugPrint('[DEBUG CREATE] Pedido creado y procesado');
      
      if (mounted) {
        // Navegar de vuelta a la lista de pedidos
        context.go('/member-orders');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido enviado al Club ${widget.clubNombre}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DEBUG CREATE] ERROR al crear pedido: $e');
      if (mounted) {
        String errorMessage = 'Error al crear pedido';
        if (e.toString().contains('membresía inactiva') || e.toString().contains('membresía no activa')) {
          errorMessage = 'Tu membresía no está activa. Contacta al anfitrión.';
        } else if (e.toString().contains('producto no disponible')) {
          errorMessage = 'Uno o más productos ya no están disponibles';
        } else if (e.toString().contains('club inactivo')) {
          errorMessage = 'El club seleccionado no está activo';
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final products = productProvider.products;
    final isLoadingProducts = productProvider.isLoading;

    if (_isLoadingMembership) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.clubNombre),
          backgroundColor: const Color(0xFF7AC142),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_membership == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.clubNombre),
          backgroundColor: const Color(0xFF7AC142),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'No tienes una membresía activa. Debes ser socio de un club para hacer pedidos.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Productos'),
            Text(
              widget.clubNombre,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF7AC142),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Lista de productos
          Expanded(
            child: isLoadingProducts
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.package, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No hay productos disponibles',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Este club no tiene productos disponibles en este momento',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => productProvider.loadAvailableProducts(widget.clubId),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final quantity = _cart[product.id] ?? 0;
                            final hasNote = _productNotes.containsKey(product.id);
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ProductImage(
                                          imageUrl: product.imageUrl.isEmpty ? null : product.imageUrl,
                                          width: 64,
                                          height: 64,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (product.description.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  product.description,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        // Botón de cantidad
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey[300]!),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove, size: 20),
                                                onPressed: quantity > 0
                                                    ? () => _updateQuantity(product.id, -1)
                                                    : null,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              Container(
                                                width: 40,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  '$quantity',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add, size: 20),
                                                onPressed: () => _updateQuantity(product.id, 1),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Botón de nota
                                        OutlinedButton.icon(
                                          onPressed: () => _showNoteDialog(product.id, product.name),
                                          icon: Icon(
                                            hasNote ? LucideIcons.fileText : LucideIcons.fileText,
                                            size: 16,
                                            color: hasNote ? const Color(0xFF7AC142) : Colors.grey,
                                          ),
                                          label: Text(
                                            hasNote ? 'Nota' : 'Agregar nota',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: hasNote ? const Color(0xFF7AC142) : Colors.grey,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          
          // Resumen y botón de crear pedido
          if (_totalItems > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tipo de consumo
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('En Lugar'),
                          selected: _tipoConsumo == 'EN_LUGAR',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _tipoConsumo = 'EN_LUGAR');
                            }
                          },
                          selectedColor: const Color(0xFF7AC142),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Para Recoger'),
                          selected: _tipoConsumo == 'PARA_RECOGER',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _tipoConsumo = 'PARA_RECOGER');
                            }
                          },
                          selectedColor: const Color(0xFF7AC142),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Nota general
                  TextField(
                    controller: _notaController,
                    decoration: InputDecoration(
                      hintText: 'Nota general del pedido (opcional)',
                      prefixIcon: const Icon(LucideIcons.fileText),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  // Botón crear pedido
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCreatingOrder ? null : _createOrder,
                      icon: _isCreatingOrder
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(LucideIcons.shoppingCart),
                      label: Text(
                        _isCreatingOrder
                            ? 'Creando pedido...'
                            : 'Crear Pedido ($_totalItems ${_totalItems == 1 ? 'item' : 'items'})',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCreatingOrder 
                            ? Colors.grey[400] 
                            : const Color(0xFF7AC142),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[400],
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),

                        
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

