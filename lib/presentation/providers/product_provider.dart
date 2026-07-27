import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

class ProductProvider extends ChangeNotifier implements SessionScopedState {
  final ProductRepository _repository;
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  ProductProvider(this._repository);

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  Future<void> clearSessionState() async {
    // Catálogo puede incluir productos LOCAL de un club / permisos de host.
    _products = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadProducts({required int hubId, required int clubId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _repository.getProducts(hubId: hubId, clubId: clubId);
    } catch (e) {
      logDebug('Error loading products');
      if (shouldPresentErrorToUser(e)) {
        _error = ErrorMapper.publicMessage(e);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAvailableProducts(int clubId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetchedProducts =
          await _repository.getAvailableProductsByClub(clubId);
      _products =
          fetchedProducts.where((p) => p.active && p.available).toList();
    } catch (e) {
      logDebug('Error loading available products');
      if (shouldPresentErrorToUser(e)) {
        _error = ErrorMapper.publicMessage(e);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleAvailability(
    int clubId,
    String productId,
    int hubId,
  ) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    final original = _products[index];
    final updated = Product(
      id: original.id,
      name: original.name,
      description: original.description,
      price: original.price,
      category: original.category,
      imageUrl: original.imageUrl,
      hubId: original.hubId,
      active: original.active,
      available: !original.available,
    );

    _products[index] = updated;
    notifyListeners();

    try {
      await _repository.toggleProductAvailability(clubId, productId);
      await loadProducts(hubId: hubId, clubId: clubId);
    } catch (e) {
      _products[index] = original;
      if (shouldPresentErrorToUser(e)) {
        _error = ErrorMapper.publicMessage(e);
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createProduct(Product product, int clubId) async {
    throw UnimplementedError('Hosts cannot create global products anymore.');
  }

  Future<void> updateProduct(Product product, int clubId) async =>
      throw UnimplementedError();

  Future<void> deleteProduct(String id, int clubId) async =>
      throw UnimplementedError();
}
