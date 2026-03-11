import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/entities/product.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../widgets/product_image.dart';

class HostProductListScreen extends StatefulWidget {
  const HostProductListScreen({super.key});

  @override
  State<HostProductListScreen> createState() => _HostProductListScreenState();
}

class _HostProductListScreenState extends State<HostProductListScreen> {
  int? _clubId;
  int? _hubId;
  bool _isLoadingClub = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadClubAndProducts();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubAndProducts() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
    final currentUser = userProvider.currentUser;

    if (currentUser != null && int.tryParse(currentUser.id) != null) {
      try {
        final club = await clubDataSource.getMyClub();
        if (club != null) {
          _clubId = club.id;
          _hubId = club.hubId;
          if (mounted) {
            // New Logic: Load all Hub products
             Provider.of<ProductProvider>(context, listen: false).loadProducts(hubId: _hubId!, clubId: _clubId!);
          }
        }
      } catch (e) {
        print('Error cargando club: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoadingClub = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi Menú (Stock)'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Color(0xFF7AC142),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF7AC142),
            tabs: [
              Tab(text: 'Globales'),
              Tab(text: 'Propios'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                 if (_clubId != null && _hubId != null) {
                   Provider.of<ProductProvider>(context, listen: false).loadProducts(hubId: _hubId!, clubId: _clubId!);
                 }
              },
            )
          ],
        ),
        body: _isLoadingClub 
            ? const Center(child: CircularProgressIndicator())
            : _clubId == null 
                ? const Center(child: Text('No se encontró tu Club.'))
                : Consumer<ProductProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (provider.error != null) {
                         return Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)));
                      }

                      // Filtrar productos según la búsqueda
                      final filteredProducts = provider.products.where((product) {
                        if (_searchQuery.isEmpty) return true;
                        return product.name.toLowerCase().contains(_searchQuery) ||
                               product.description.toLowerCase().contains(_searchQuery);
                      }).toList();

                      final globalProducts = filteredProducts.where((p) => p.tipo == 'GLOBAL').toList();
                      final ownProducts = filteredProducts.where((p) => p.tipo == 'LOCAL').toList();

                      return Column(
                        children: [
                          // Barra de búsqueda
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Buscar productos...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                          ),
                          // Tabs content
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildProductList(globalProducts, provider, isGlobal: true),
                                _buildProductList(ownProducts, provider, isGlobal: false),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
        // El botón de + Nuevo se movió al tab de Propios

      ),
    );
  }

  Widget _buildProductList(List<Product> products, ProductProvider provider, {required bool isGlobal}) {
    return Stack(
      children: [
        if (products.isEmpty)
          Center(
            child: Text(
              _searchQuery.isNotEmpty 
                  ? 'No se encontraron resultados para "$_searchQuery"'
                  : (isGlobal ? 'No hay productos globales disponibles.' : 'Aún no has creado productos propios.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: _buildProductImage(product),
                  title: Text(
                    product.name, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: product.available ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.description,
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Puntos Volumen: ${product.puntosValor}',
                        style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF7AC142)),
                      ),
                      if (!isGlobal && product.estadoAprobacion != 'APROBADO') 
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: product.estadoAprobacion == 'RECHAZADO' ? Colors.red.shade100 : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.estadoAprobacion == 'RECHAZADO' ? 'Rechazado' : 'Pendiente de aprobación',
                            style: TextStyle(
                              fontSize: 12,
                              color: product.estadoAprobacion == 'RECHAZADO' ? Colors.red.shade900 : Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                    ],
                  ),
                  trailing: Switch(
                    activeColor: const Color(0xFF7AC142),
                    value: product.available && product.estadoAprobacion == 'APROBADO',
                    onChanged: product.estadoAprobacion == 'APROBADO' ? (bool value) {
                      provider.toggleAvailability(_clubId!, product.id, _hubId!);
                    } : null,
                  ),
                  // Opcional: permitir editar productos propios con onLongPress o algo similar
                  onLongPress: !isGlobal ? () {
                    context.push('/host/products/edit', extra: {
                      'clubId': _clubId!,
                      'product': product,
                    });
                  } : null,
                ),
              );
            },
          ),
          
        if (!isGlobal)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'addProductFab',
              backgroundColor: const Color(0xFF7AC142),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nuevo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                context.push('/host/products/proposal');
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProductImage(Product product) {
    return ProductImage(
      imageUrl: product.imageUrl.isEmpty ? null : product.imageUrl,
      width: 50,
      height: 50,
    );
  }

}
