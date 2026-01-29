import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/entities/product.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../../data/datasources/remote/club_remote_data_source.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
        final club = await clubDataSource.getClubByHostId(int.parse(currentUser.id));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Menú (Stock)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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

                    if (provider.products.isEmpty) {
                      return const Center(child: Text('El catálogo del Hub está vacío.'));
                    }

                    // Filtrar productos según la búsqueda
                    final filteredProducts = provider.products.where((product) {
                      if (_searchQuery.isEmpty) return true;
                      return product.name.toLowerCase().contains(_searchQuery) ||
                             product.description.toLowerCase().contains(_searchQuery);
                    }).toList();

                    if (filteredProducts.isEmpty && _searchQuery.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No se encontraron productos\nque coincidan con "$_searchQuery"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

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
                        // Lista de productos
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: SwitchListTile(
                            activeColor: const Color(0xFF7AC142),
                            title: Text(
                              product.name, 
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: product.available ? Colors.black : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              product.description,
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: product.available,
                            onChanged: (bool value) {
                              provider.toggleAvailability(_clubId!, product.id, _hubId!);
                            },
                            secondary: _buildProductImage(product),
                          ),
                        );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildProductImage(Product product) {
    if (product.imageUrl.isNotEmpty) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(image: NetworkImage(product.imageUrl), fit: BoxFit.cover),
        ),
      );
    }
    return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(LucideIcons.soup, color: Colors.grey),
    );
  }

}
