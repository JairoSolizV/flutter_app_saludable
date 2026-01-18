import '../entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts({int? clubId});
  Future<Product?> getProductById(String id);
  Future<void> createProduct(Product product, int clubId);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
}
