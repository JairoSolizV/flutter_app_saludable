import 'package:flutter/foundation.dart';

import '../../data/datasources/remote/order_remote_data_source.dart';
import '../../data/datasources/remote/product_remote_data_source.dart';
import '../../data/datasources/remote/combo_remote_data_source.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/combo.dart';

class CounterSaleItem {
  final Product product;
  int quantity;
  String note;
  int? comboId;
  String? comboNombre;

  CounterSaleItem({
    required this.product,
    this.quantity = 1,
    this.note = '',
    this.comboId,
    this.comboNombre,
  });
}

class CounterSaleProvider extends ChangeNotifier {
  final ProductRemoteDataSource _productDataSource;
  final OrderRemoteDataSource _orderDataSource;
  final ComboRemoteDataSource? _comboDataSource;

  CounterSaleProvider(this._productDataSource, this._orderDataSource, [this._comboDataSource]);

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
  List<Combo> _combos = [];
  final Map<String, CounterSaleItem> _cart = {};

  List<Product> get generalProducts =>
      _products.where((p) => p.tipo == 'GLOBAL').toList();
  List<Product> get clubSpecialties =>
      _products.where((p) => p.tipo == 'LOCAL').toList();
  List<Combo> get activeCombos =>
      _combos.where((c) => c.activo).toList();
  List<CounterSaleItem> get cartItems => _cart.values.toList();
  int get totalItems =>
      _cart.values.fold(0, (sum, item) => sum + item.quantity);
  bool get canSubmit => _cart.isNotEmpty && !isSubmitting;
  static const int maxSabores = 3;
  int get distinctProducts => _cart.length;
  bool get isMaxSaboresReached => _cart.length >= maxSabores;
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
      // Cargar combos del club
      if (_comboDataSource != null) {
        try {
          _combos = await _comboDataSource!.getCombosByClub(clubId!);
        } catch (e) {
          debugPrint('[COUNTER SALE] Error cargando combos: $e');
          _combos = [];
        }
      }
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

  bool addProduct(Product product) {
    final existing = _cart[product.id];
    if (existing == null) {
      if (_cart.length >= maxSabores) return false;
      _cart[product.id] = CounterSaleItem(product: product, quantity: 1);
    } else {
      existing.quantity += 1;
    }
    notifyListeners();
    return true;
  }

  /// Agrega un combo completo al carrito.
  /// Expande los items del combo como productos individuales con referencia al combo.
  /// Retorna true si se pudo agregar, false si no hay espacio.
  bool addCombo(Combo combo) {
    // Verificar que hay espacio para los productos del combo que aún no están en el carrito
    final newProductIds = combo.items
        .map((item) => item.productoId.toString())
        .where((id) => !_cart.containsKey(id))
        .toSet();

    if (_cart.length + newProductIds.length > maxSabores) {
      return false;
    }

    // Agregar cada item del combo
    for (final comboItem in combo.items) {
      final productId = comboItem.productoId.toString();
      final existing = _cart[productId];

      // Buscar el producto en el catálogo cargado
      final product = _products.where((p) => p.id == productId).firstOrNull;
      if (product == null) continue;

      if (existing != null) {
        existing.quantity += comboItem.cantidad;
        // Actualizar referencia de combo si no tenía
        existing.comboId ??= combo.id;
        existing.comboNombre ??= combo.nombre;
      } else {
        _cart[productId] = CounterSaleItem(
          product: product,
          quantity: comboItem.cantidad,
          comboId: combo.id,
          comboNombre: combo.nombre,
          note: comboItem.saborNombre != null ? 'Sabor: ${comboItem.saborNombre}' : '',
        );
      }
    }
    notifyListeners();
    return true;
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
        final map = <String, dynamic>{
          'productoId': productoId,
          'cantidad': item.quantity,
          'nota': item.note.trim(),
        };
        if (item.comboId != null) {
          map['comboId'] = item.comboId;
        }
        return map;
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
