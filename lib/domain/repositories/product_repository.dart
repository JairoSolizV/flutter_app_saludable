import '../entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts({required int hubId, required int clubId});
  Future<Product?> getProductById(String id);
  Future<void> createProduct(Product product, int clubId);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<void> toggleProductAvailability(int clubId, String productId);
}
