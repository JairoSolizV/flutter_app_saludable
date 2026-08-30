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
  final Set<String> _productsToggling = {};

  ProductProvider(this._repository);

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isToggling(String productId) => _productsToggling.contains(productId);

  @override
  Future<void> clearSessionState() async {
    // Catálogo puede incluir productos LOCAL de un club / permisos de host.
    _products = [];
    _isLoading = false;
    _error = null;
    _productsToggling.clear();
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
    if (_productsToggling.contains(productId)) return;

    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    _productsToggling.add(productId);
    notifyListeners();

    final original = _products[index];
    final updated = original.copyWith(available: !original.available);
    _products[index] = updated;
    notifyListeners();

    try {
      await _repository.toggleProductAvailability(clubId, productId);
      try {
        _products = await _repository.getProducts(hubId: hubId, clubId: clubId);
      } catch (e) {
        logDebug('Error refreshing products after toggle');
      }
    } catch (e) {
      final currentIndex = _products.indexWhere((p) => p.id == productId);
      if (currentIndex != -1) {
        _products[currentIndex] = original;
      }
      notifyListeners();
      rethrow;
    } finally {
      _productsToggling.remove(productId);
      notifyListeners();
    }
  }

  Future<void> createProduct(Product product, int clubId) async {
    throw UnimplementedError('Hosts cannot create global products anymore.');
  }

  Future<void> updateProduct(Product product, int clubId) async =>
      throw UnimplementedError();

  /// Legacy. El anfitrión no desactiva ni borra productos.
  /// Disponibilidad: [toggleAvailability] → PATCH /clubes/{clubId}/productos/{id}/toggle.
  @Deprecated('Usar toggleAvailability. No llama /activar ni /desactivar.')
  Future<void> deleteProduct(String id, int clubId) async =>
      throw UnsupportedError(
        'El anfitrión no puede desactivar productos de forma global. '
        'Usa el switch de disponibilidad del club.',
      );
}
