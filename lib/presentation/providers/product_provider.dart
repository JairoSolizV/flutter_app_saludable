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

  Future<void> loadProducts({int? clubId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _repository.getProducts(clubId: clubId);
    } catch (e) {
      print('Error loading products: $e');
      _error = e.toString(); // Capture error for UI
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createProduct(Product product, int clubId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.createProduct(product, clubId);
      // Recargar lista después de crear
      await loadProducts(clubId: clubId);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProduct(Product product, int clubId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.updateProduct(product);
      await loadProducts(clubId: clubId);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProduct(String id, int clubId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.deleteProduct(id);
      await loadProducts(clubId: clubId);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
