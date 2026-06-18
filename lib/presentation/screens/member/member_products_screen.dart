import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../domain/entities/product.dart';
import '../../../data/datasources/remote/product_remote_data_source.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';
import '../../widgets/product_image.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/presentation/widgets/refreshable_scroll_view.dart';

class MemberProductsScreen extends StatefulWidget {
  final String clubId;
  final Club? club;

  const MemberProductsScreen({
    super.key,
    required this.clubId,
    this.club,
  });

  @override
  State<MemberProductsScreen> createState() => _MemberProductsScreenState();
}

class _MemberProductsScreenState extends State<MemberProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final productDataSource = Provider.of<ProductRemoteDataSource>(context, listen: false);
      final products = await productDataSource.getAvailableProductsByClub(int.parse(widget.clubId));
      
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Menú', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            if (widget.club != null)
              Text(
                widget.club!.nombreClub,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _error != null
              ? RefreshableScrollView(
                  onRefresh: _loadProducts,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.alertCircle, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProducts,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _products.isEmpty
                  ? RefreshableScrollView(
                      onRefresh: _loadProducts,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.packageOpen, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No hay productos disponibles',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.club?.nombreClub ?? 'en este club',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      color: AppTheme.primaryColor,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return _buildProductCard(product);
                        },
                      ),
                    ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProductImage(
              imageUrl: product.imageUrl.isEmpty ? null : product.imageUrl,
              width: 80,
              height: 80,
            ),
            const SizedBox(width: 16),
            
            // Product Info
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Disponible',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Add to Cart Button
            IconButton(
              onPressed: () {
                // TODO: Add to cart functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${product.name} añadido al carrito'),
                    backgroundColor: AppTheme.primaryColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(LucideIcons.shoppingCart),
              color: const Color(0xFFFF6B00),
              iconSize: 28,
            ),
          ],
        ),
      ),
    );
  }
}
