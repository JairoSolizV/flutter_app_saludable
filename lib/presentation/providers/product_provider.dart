import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

class ProductProvider extends ChangeNotifier {
  final ProductRepository _repository;
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error; // Store error message

  ProductProvider(this._repository);

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProducts({required int hubId, required int clubId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _repository.getProducts(hubId: hubId, clubId: clubId);
    } catch (e) {
      print('Error loading products: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Método para socios: cargar solo productos disponibles del club
  Future<void> loadAvailableProducts(int clubId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _repository.getAvailableProductsByClub(clubId);
    } catch (e) {
      print('Error loading available products: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleAvailability(int clubId, String productId, int hubId) async {
    // Optimistic update
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final original = _products[index];
      // Create modified copy
      final updated = Product(
        id: original.id,
        name: original.name,
        description: original.description,
        price: original.price,
        category: original.category,
        imageUrl: original.imageUrl,
        hubId: original.hubId,
        active: original.active,
        available: !original.available, // Toggle
      );
      
      _products[index] = updated;
      notifyListeners();

      try {
        await _repository.toggleProductAvailability(clubId, productId);
        // Recargar productos para asegurar que el estado se sincronice correctamente con el backend
        // Esto garantiza que el estado disponible se mantenga correctamente
        await loadProducts(hubId: hubId, clubId: clubId);
      } catch (e) {
        // Revert on error
        _products[index] = original;
        // Limpiar el mensaje de error removiendo prefijos innecesarios
        String errorMessage = e.toString().replaceAll('Exception: ', '').trim();
        _error = errorMessage;
        notifyListeners();
        // Re-lanzar el error para que la UI pueda manejarlo si es necesario
        rethrow;
      }
    }
  }

  // Legacy/Unused create/update/delete methods kept for potential future admin use, 
  // but Host flow is now toggle-only. We temporarily disable them or update them to use new load signature.
  Future<void> createProduct(Product product, int clubId) async {
     // ... (Implementation pending decision if Hosts can CREATE global products. Assuming NO for now).
     throw UnimplementedError("Hosts cannot create global products anymore.");
  }
  Future<void> updateProduct(Product product, int clubId) async => throw UnimplementedError();
  Future<void> deleteProduct(String id, int clubId) async => throw UnimplementedError();
}
