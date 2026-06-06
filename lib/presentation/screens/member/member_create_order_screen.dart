import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/product_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/club_membership.dart';
import '../../../domain/entities/combo.dart';
import '../../../data/datasources/remote/membresia_remote_data_source.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';
import '../../../data/datasources/remote/combo_remote_data_source.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

class MemberCreateOrderScreen extends StatefulWidget {
  const MemberCreateOrderScreen({super.key});

  @override
  State<MemberCreateOrderScreen> createState() => _MemberCreateOrderScreenState();
}

class _MemberCreateOrderScreenState extends State<MemberCreateOrderScreen> {
  static const int _maxSabores = 3;
  // Mapa de ProductoID -> Cantidad
  final Map<String, int> _cart = {};
  // Mapa de ProductoID -> Nota
  final Map<String, String> _productNotes = {};
  ClubMembership? _membership;
  bool _isLoadingMembership = true;
  String _tipoConsumo = 'EN_LUGAR'; // 'EN_LUGAR' o 'PARA_RECOGER'
  final TextEditingController _notaController = TextEditingController();
  
  // Combos state
  List<Combo> _combos = [];
  bool _isLoadingCombos = false;
  // Mapa de ProductoID -> comboId (para trazabilidad)
  final Map<String, int> _productComboIds = {};

  // Nuevos campos para selector de club
  List<Club> _availableClubes = []; // Lista de clubes del HUB
  int? _selectedClubId; // Club seleccionado para el pedido
  bool _isLoadingClubes = false;

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
        
        // Obtener el club de la membresía para obtener el hubId
        final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
        final club = await clubDataSource.getClubById(membership.clubId);
        
        if (club != null) {
          // Cargar todos los clubes del mismo HUB
          await _loadClubesByHub(club.hubId);
          
          // Establecer el club seleccionado por defecto como el club de la membresía
          setState(() {
            _selectedClubId = membership.clubId;
          });
          
          // Cargar productos disponibles del club seleccionado
          if (mounted && _selectedClubId != null) {
            await Provider.of<ProductProvider>(context, listen: false)
                .loadAvailableProducts(_selectedClubId!);
            _loadCombos(_selectedClubId!);
          }
        }
      } else {
        setState(() => _isLoadingMembership = false);
      }
    } catch (e) {
      debugPrint('Error loading membership: $e');
      setState(() => _isLoadingMembership = false);
    }
  }

  Future<void> _loadClubesByHub(int hubId) async {
    try {
      setState(() => _isLoadingClubes = true);
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      final clubes = await clubDataSource.getClubesByHub(hubId);
      
      if (mounted) {
        setState(() {
          _availableClubes = clubes;
          _isLoadingClubes = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading clubes: $e');
      if (mounted) {
        setState(() => _isLoadingClubes = false);
      }
    }
  }

  Future<void> _onClubChanged(int? newClubId) async {
    if (newClubId == null || newClubId == _selectedClubId) return;
    
    setState(() {
      _selectedClubId = newClubId;
      _cart.clear(); // Limpiar carrito al cambiar de club
      _productNotes.clear();
      _productComboIds.clear();
      _combos = [];
    });

    // Cargar productos del nuevo club seleccionado
    if (mounted) {
      await Provider.of<ProductProvider>(context, listen: false)
          .loadAvailableProducts(newClubId);
      _loadCombos(newClubId);
    }
  }

  Future<void> _loadCombos(int clubId) async {
    setState(() => _isLoadingCombos = true);
    try {
      final comboDs = Provider.of<ComboRemoteDataSource>(context, listen: false);
      final result = await comboDs.getCombosByClub(clubId);
      if (mounted) {
        setState(() {
          _combos = result.where((c) => c.activo).toList();
          _isLoadingCombos = false;
        });
      }
    } catch (e) {
      debugPrint('[MEMBER ORDER] Error cargando combos: $e');
      if (mounted) setState(() => _isLoadingCombos = false);
    }
  }

  void _addCombo(Combo combo, List<dynamic> products) {
    // Check space: count new distinct products from this combo
    final newIds = combo.items
        .map((item) => item.productoId.toString())
        .where((id) => !_cart.containsKey(id))
        .toSet();

    if (_cart.length + newIds.length > _maxSabores) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay espacio para este combo (máx. $_maxSabores sabores).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      for (final comboItem in combo.items) {
        final productId = comboItem.productoId.toString();
        final existingQty = _cart[productId] ?? 0;
        _cart[productId] = existingQty + comboItem.cantidad;
        _productComboIds[productId] = combo.id!;
        if (comboItem.saborNombre != null) {
          _productNotes[productId] = 'Sabor: ${comboItem.saborNombre}';
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Combo "${combo.nombre}" agregado'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1200),
      ),
    );
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

    // Obtener nombre del club seleccionado
    String selectedClubName = _membership!.clubNombre;
    if (_selectedClubId != null && _availableClubes.isNotEmpty) {
      final selectedClub = _availableClubes.firstWhere(
        (club) => club.id == _selectedClubId,
        orElse: () => Club(
          id: 0,
          hubId: 0,
          hubNombre: '',
          anfitrionId: 0,
          anfitrionNombre: '',
          nombreClub: '',
          direccion: '',
          horario: '',
          lat: 0.0,
          lng: 0.0,
          estado: '',
        ),
      );
      if (selectedClub.id != 0) {
        selectedClubName = selectedClub.nombreClub;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nuevo Pedido'),
            Text(
              selectedClubName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Selector de Club
          if (_availableClubes.length > 1)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona el club para tu pedido:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedClubId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.store),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _availableClubes.map<DropdownMenuItem<int>>((club) {
                      return DropdownMenuItem<int>(
                        value: club.id,
                        child: Text(club.nombreClub),
                      );
                    }).toList(),
                    onChanged: _isLoadingClubes ? null : (int? newClubId) {
                      _onClubChanged(newClubId);
                    },
                  ),
                ],
              ),
            )
          else if (_availableClubes.length == 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.store, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Club: ${_availableClubes.first.nombreClub}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          
          if (productProvider.isLoading)
            const LinearProgressIndicator()
          else if (productProvider.error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${productProvider.error}', style: const TextStyle(color: Colors.red)),
            )
          else if (products.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      _selectedClubId == null 
                        ? 'Selecciona un club para ver productos'
                        : 'No hay productos disponibles en este club en este momento.',
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                // Combos section + products
                itemCount: products.length + (_combos.isNotEmpty ? _combos.length + 1 : 0),
              itemBuilder: (context, index) {
                // Section header for combos
                if (_combos.isNotEmpty && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.fastfood, color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            const Text('Combos disponibles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(),
                      ],
                    ),
                  );
                }

                // Combo cards
                if (_combos.isNotEmpty && index > 0 && index <= _combos.length) {
                  final combo = _combos[index - 1];
                  final itemsText = combo.items.map((item) {
                    String label = '${item.cantidad}x ${item.productoNombre}';
                    if (item.saborNombre != null) label += ' (${item.saborNombre})';
                    return label;
                  }).join(' + ');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(Icons.fastfood, color: Colors.white, size: 18),
                      ),
                      title: Text(combo.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(itemsText, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          Text('${combo.puntosValor} pts', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                        onPressed: () => _addCombo(combo, products),
                      ),
                    ),
                  );
                }

                // Adjust index for products
                final productIndex = _combos.isNotEmpty ? index - _combos.length - 1 : index;
                final product = products[productIndex];
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
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: (qty == 0 && _cart.length >= _maxSabores)
                                ? Colors.grey
                                : AppTheme.primaryColor,
                          ),
                          onPressed: (qty == 0 && _cart.length >= _maxSabores)
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Solo puedes seleccionar hasta 3 sabores por combo.'),
                                      backgroundColor: Colors.orange,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              : () {
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
                            value: 'PARA_RECOGER',
                            label: Text('Para Recoger'),
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
                      Text('$totalItems', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Sabores seleccionados: ', style: TextStyle(fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cart.length >= _maxSabores ? Colors.orange.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _cart.length >= _maxSabores ? Colors.orange : Colors.green,
                          ),
                        ),
                        child: Text(
                          '${_cart.length}/$_maxSabores',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _cart.length >= _maxSabores ? Colors.orange.shade800 : Colors.green.shade800,
                          ),
                        ),
                      ),
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
                             productName: product.name,
                             comboId: _productComboIds[entry.key],
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

                        // Validar que se haya seleccionado un club
                        if (_selectedClubId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Por favor selecciona un club para hacer el pedido'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        debugPrint('[DEBUG CREATE] Creando pedido con:');
                        debugPrint('[DEBUG CREATE]   clubId seleccionado: $_selectedClubId');
                        debugPrint('[DEBUG CREATE]   clubId membresía: ${_membership!.clubId}');
                        debugPrint('[DEBUG CREATE]   membresiaId: ${_membership!.id}');
                        debugPrint('[DEBUG CREATE]   userId: ${user.id}');
                        debugPrint('[DEBUG CREATE]   items: ${items.length}');
                        debugPrint('[DEBUG CREATE]   tipoConsumo: $_tipoConsumo');

                        final newOrder = OrderEntity(
                          id: orderId,
                          userId: user.id,
                          clubId: _selectedClubId!, // Usar el club seleccionado, no el de la membresía
                          membresiaId: _membership!.id,
                          tipoConsumo: _tipoConsumo, // 'EN_LUGAR' o 'PARA_RECOGER'
                          observaciones: _notaController.text.trim(), // Nota general del pedido
                          status: 'pending',
                          createdAt: DateTime.now(),
                          items: items,
                          isSynced: false
                        );

                        debugPrint('[DEBUG CREATE] OrderEntity creado - clubId: ${newOrder.clubId}, membresiaId: ${newOrder.membresiaId}');
                        
                        try {
                          await orderProvider.createOrder(newOrder);
                          debugPrint('[DEBUG CREATE] Pedido creado y procesado');
                          
                          if (context.mounted) {
                            context.pop(); // Volver a lista
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pedido creado correctamente. Verifica los logs para confirmar el envío al backend.'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('[DEBUG CREATE] ERROR al crear pedido: $e');
                          if (context.mounted) {
                            final errorMsg = e.toString();
                            final isMaxSabores = errorMsg.contains('MAX_SABORES_EXCEDIDO') ||
                                errorMsg.contains('3 sabores');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isMaxSabores
                                    ? 'Máximo 3 sabores por combo. Reduce los productos seleccionados.'
                                    : 'Error al crear pedido: $e'),
                                backgroundColor: isMaxSabores ? Colors.orange : Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
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
