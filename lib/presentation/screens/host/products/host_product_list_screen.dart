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
  bool _isLoadingClub = true;

  @override
  void initState() {
    super.initState();
    _loadClubAndProducts();
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
          if (mounted) {
            // Cargar productos del club
             Provider.of<ProductProvider>(context, listen: false).loadProducts(clubId: _clubId);
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
        title: const Text('Mi Menú'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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
                       // Si hay error (ej: fallo de red), mostramos el error Y los datos locales si existen
                       // Pero es útil saber que hubo error.
                       return Column(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(8),
                             color: Colors.red[100],
                             width: double.infinity,
                             child: Text('Error de sincronización: ${provider.error}', style: const TextStyle(color: Colors.red)),
                           ),
                           Expanded(
                             child: provider.products.isEmpty 
                               ? const Center(child: Text('No hay productos.'))
                               : _buildProductList(provider.products, context),
                           ),
                         ],
                       );
                    }

                    if (provider.products.isEmpty) {
                      return const Center(child: Text('No tienes productos en tu menú aún.'));
                    }

                    return _buildProductList(provider.products, context);
                  },
                ),
      floatingActionButton: _clubId != null ? FloatingActionButton.extended(
        onPressed: () {
           context.push('/host/products/new', extra: _clubId);
        },
        label: const Text('Nuevo Producto'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF7AC142),
      ) : null,
    );
  }

  Widget _buildProductList(List<Product> products, BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                image: product.imageUrl.isNotEmpty 
                    ? DecorationImage(image: NetworkImage(product.imageUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: product.imageUrl.isEmpty 
                  ? const Icon(Icons.fastfood, color: Colors.grey) 
                  : null,
            ),
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${product.category} • Bs. ${product.price.toStringAsFixed(2)}'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () {
              // Navegar a editar pasando el producto y el clubId
              context.push('/host/products/edit', extra: {'clubId': _clubId, 'product': product});
            },
          ),
        );
      },
    );
  }

}
