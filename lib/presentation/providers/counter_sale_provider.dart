import 'package:flutter/foundation.dart';

import '../../data/datasources/remote/order_remote_data_source.dart';
import '../../data/datasources/remote/product_remote_data_source.dart';
import '../../domain/entities/product.dart';

class CounterSaleItem {
  final Product product;
  int quantity;
  String note;

  CounterSaleItem({
    required this.product,
    this.quantity = 1,
    this.note = '',
  });
}

class CounterSaleProvider extends ChangeNotifier {
  final ProductRemoteDataSource _productDataSource;
  final OrderRemoteDataSource _orderDataSource;

  CounterSaleProvider(this._productDataSource, this._orderDataSource);

  bool isCatalogLoading = false;
  bool isSubmitting = false;
  bool submitSuccess = false;
  String? catalogError;
  String? submitError;

  int? clubId;
  int? hubId;
  String socioCodigo = '';
  String tipoConsumo = 'EN_LUGAR';
  String observaciones = '';

  List<Product> _products = [];
  final Map<String, CounterSaleItem> _cart = {};

  List<Product> get generalProducts =>
      _products.where((p) => p.tipo == 'GLOBAL').toList();
  List<Product> get clubSpecialties =>
      _products.where((p) => p.tipo == 'LOCAL').toList();
  List<CounterSaleItem> get cartItems => _cart.values.toList();
  int get totalItems =>
      _cart.values.fold(0, (sum, item) => sum + item.quantity);
  bool get canSubmit => _cart.isNotEmpty && !isSubmitting;
  int get totalPuntos =>
      _cart.values.fold(0, (sum, item) => sum + (item.product.puntosValor * item.quantity));

  Future<void> init({
    required int clubId,
    required int hubId,
  }) async {
    this.clubId = clubId;
    this.hubId = hubId;
    await loadCatalog();
  }

  Future<void> loadCatalog() async {
    if (clubId == null || hubId == null) return;

    isCatalogLoading = true;
    catalogError = null;
    notifyListeners();

    try {
      _products = await _productDataSource.getProducts(
        hubId: hubId!,
        clubId: clubId!,
      );
    } catch (e) {
      catalogError = e.toString().replaceAll('Exception: ', '');
    } finally {
      isCatalogLoading = false;
      notifyListeners();
    }
  }

  void setSocioCodigo(String value) {
    socioCodigo = value;
    notifyListeners();
  }

  void setObservaciones(String value) {
    observaciones = value;
    notifyListeners();
  }

  void setTipoConsumo(String value) {
    tipoConsumo = value;
    notifyListeners();
  }

  void addProduct(Product product) {
    final existing = _cart[product.id];
    if (existing == null) {
      _cart[product.id] = CounterSaleItem(product: product, quantity: 1);
    } else {
      existing.quantity += 1;
    }
    notifyListeners();
  }

  void increaseQty(String productId) {
    final item = _cart[productId];
    if (item == null) return;
    item.quantity += 1;
    notifyListeners();
  }

  void decreaseQty(String productId) {
    final item = _cart[productId];
    if (item == null) return;
    item.quantity -= 1;
    if (item.quantity <= 0) {
      _cart.remove(productId);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _cart.remove(productId);
    notifyListeners();
  }

  void setItemNote(String productId, String note) {
    final item = _cart[productId];
    if (item == null) return;
    item.note = note;
    notifyListeners();
  }

  Future<bool> submitCounterSale() async {
    if (clubId == null) {
      submitError = 'No se encontró club para registrar la venta.';
      notifyListeners();
      return false;
    }
    if (_cart.isEmpty) {
      submitError = 'Debes agregar al menos un producto.';
      notifyListeners();
      return false;
    }
    if (isSubmitting) return false;

    isSubmitting = true;
    submitError = null;
    submitSuccess = false;
    notifyListeners();

    try {
      final items = _cart.values.map((item) {
        final productoId = int.tryParse(item.product.id);
        if (productoId == null) {
          throw Exception('Producto inválido en ticket: id=${item.product.id}');
        }
        return {
          'productoId': productoId,
          'cantidad': item.quantity,
          'nota': item.note.trim(),
        };
      }).toList();

      await _orderDataSource.createCounterSale(
        clubId: clubId!,
        socioCodigo: socioCodigo.trim().isEmpty ? null : socioCodigo.trim(),
        tipoConsumo: tipoConsumo,
        observaciones: observaciones.trim(),
        items: items,
      );

      submitSuccess = true;
      return true;
    } catch (e, st) {
      debugPrint('[COUNTER SALE] submit error: $e');
      debugPrint('[COUNTER SALE] stack: $st');
      submitError = e.toString().replaceAll('Exception: ', '');
      submitSuccess = false;
      // NO limpiamos ticket en error.
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  void resetSale() {
    socioCodigo = '';
    tipoConsumo = 'EN_LUGAR';
    observaciones = '';
    _cart.clear();
    submitError = null;
    submitSuccess = false;
    notifyListeners();
  }
}
