import 'package:flutter/foundation.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/constants/counter_sale_payment_types.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';

import '../../data/datasources/remote/order_remote_data_source.dart';
import '../../data/datasources/remote/product_remote_data_source.dart';
import '../../data/datasources/remote/combo_remote_data_source.dart';
import '../../domain/entities/combo.dart';
import '../../domain/entities/combo_cart_item.dart';
import '../../domain/entities/counter_sale_product_line.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_option_selection.dart';

class CounterSaleProvider extends ChangeNotifier implements SessionScopedState {
  final ProductRemoteDataSource _productDataSource;
  final OrderRemoteDataSource _orderDataSource;
  final ComboRemoteDataSource? _comboDataSource;

  CounterSaleProvider(
    this._productDataSource,
    this._orderDataSource, [
    this._comboDataSource,
  ]);

  bool isCatalogLoading = false;
  bool isSubmitting = false;
  bool submitSuccess = false;
  String? catalogError;
  String? submitError;

  int? clubId;
  int? hubId;
  String socioCodigo = '';
  String tipoConsumo = 'EN_LUGAR';
  String? tipoPago;
  String observaciones = '';

  List<Product> _products = [];
  List<Combo> _combos = [];
  final Map<String, CounterSaleProductLine> _productCart = {};
  final Map<String, ComboCartItem> _comboCart = {};

  List<Product> get generalProducts =>
      _products.where((p) => p.tipo == 'GLOBAL').toList();
  List<Product> get clubSpecialties =>
      _products.where((p) => p.tipo == 'LOCAL').toList();
  List<Combo> get activeCombos =>
      _combos.where((c) => c.activo).toList(growable: false);
  Map<String, Product> get productsById => {
        for (final p in _products) p.id: p,
      };
  List<CounterSaleProductLine> get cartLines => _productCart.values.toList();
  List<ComboCartItem> get comboCartLines => _comboCart.values.toList();
  int get totalProductUnits =>
      _productCart.values.fold(0, (sum, line) => sum + line.quantity);
  int get totalComboUnits =>
      _comboCart.values.fold(0, (sum, line) => sum + line.quantity);
  int get totalCartUnits => totalProductUnits + totalComboUnits;
  bool get hasCartItems => _productCart.isNotEmpty || _comboCart.isNotEmpty;

  /// Compat: cantidad total de unidades en carrito (productos + combos).
  int get totalItems => totalCartUnits;

  double get totalBs =>
      _productCart.values.fold(0.0, (sum, line) => sum + line.subtotal) +
      _comboCart.values.fold(0.0, (sum, line) => sum + line.lineTotal);

  int get totalPuntos =>
      _productCart.values.fold(0, (sum, line) => sum + line.totalPoints) +
      _comboCart.values.fold(0, (sum, line) => sum + line.points * line.quantity);

  bool get canSubmit =>
      hasCartItems &&
      !isSubmitting &&
      tipoPago != null &&
      CounterSalePaymentTypes.backendValues.contains(tipoPago);

  bool get combosEnabled => _comboDataSource != null;

  @override
  Future<void> clearSessionState() async {
    clubId = null;
    hubId = null;
    socioCodigo = '';
    tipoConsumo = 'EN_LUGAR';
    tipoPago = null;
    observaciones = '';
    _products = [];
    _combos = [];
    _productCart.clear();
    _comboCart.clear();
    isCatalogLoading = false;
    isSubmitting = false;
    submitSuccess = false;
    catalogError = null;
    submitError = null;
    notifyListeners();
  }

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
      if (_comboDataSource != null) {
        _combos = await _comboDataSource.getCombosByClub(clubId!);
      } else {
        _combos = [];
      }
    } catch (e) {
      if (shouldPresentErrorToUser(e)) {
        catalogError = ErrorMapper.publicMessage(e);
      }
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

  void setTipoPago(String? value) {
    tipoPago = value;
    notifyListeners();
  }

  void addProductLine({
    required Product product,
    List<ProductOptionSelection> selections = const [],
    int quantity = 1,
  }) {
    if (quantity < 1) return;
    final key = ProductOptionSelection.cartKey(product.id, selections);
    final existing = _productCart[key];
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      _productCart[key] = CounterSaleProductLine(
        product: product,
        selections: selections,
        quantity: quantity,
      );
    }
    notifyListeners();
  }

  void addComboLine(ComboCartItem item) {
    if (item.quantity < 1 || !item.hasConfiguredPrice) return;
    final key = item.configKey;
    final existing = _comboCart[key];
    if (existing != null) {
      _comboCart[key] = existing.copyWith(
        quantity: existing.quantity + item.quantity,
      );
    } else {
      _comboCart[key] = item;
    }
    notifyListeners();
  }

  void increaseQty(String configKey) {
    final line = _productCart[configKey];
    if (line == null) return;
    line.quantity += 1;
    notifyListeners();
  }

  void decreaseQty(String configKey) {
    final line = _productCart[configKey];
    if (line == null) return;
    line.quantity -= 1;
    if (line.quantity <= 0) {
      _productCart.remove(configKey);
    }
    notifyListeners();
  }

  void removeLine(String configKey) {
    _productCart.remove(configKey);
    notifyListeners();
  }

  void setLineNote(String configKey, String note) {
    final line = _productCart[configKey];
    if (line == null) return;
    line.note = note;
    notifyListeners();
  }

  void increaseComboQty(String configKey) {
    final line = _comboCart[configKey];
    if (line == null) return;
    _comboCart[configKey] = line.copyWith(quantity: line.quantity + 1);
    notifyListeners();
  }

  void decreaseComboQty(String configKey) {
    final line = _comboCart[configKey];
    if (line == null) return;
    if (line.quantity <= 1) {
      _comboCart.remove(configKey);
    } else {
      _comboCart[configKey] = line.copyWith(quantity: line.quantity - 1);
    }
    notifyListeners();
  }

  void removeComboLine(String configKey) {
    _comboCart.remove(configKey);
    notifyListeners();
  }

  Future<bool> submitCounterSale() async {
    if (clubId == null) {
      submitError = 'No se encontró club para registrar la venta.';
      notifyListeners();
      return false;
    }
    if (!hasCartItems) {
      submitError = 'Debes agregar al menos un producto o combo.';
      notifyListeners();
      return false;
    }
    if (tipoPago == null ||
        !CounterSalePaymentTypes.backendValues.contains(tipoPago)) {
      submitError = 'Selecciona una forma de pago.';
      notifyListeners();
      return false;
    }
    if (isSubmitting) return false;

    isSubmitting = true;
    submitError = null;
    submitSuccess = false;
    notifyListeners();

    try {
      final items = _productCart.values.map((line) {
        final productoId = int.tryParse(line.product.id);
        if (productoId == null) {
          throw Exception('Producto inválido en ticket: id=${line.product.id}');
        }
        final opciones = line.selections
            .map((s) => s.toOrderItemOption().toApiMap())
            .toList();
        return <String, dynamic>{
          'productoId': productoId,
          'cantidad': line.quantity,
          'nota': line.note.trim(),
          'opciones': opciones,
        };
      }).toList();

      final combos =
          _comboCart.values.map((line) => line.toCounterSaleApiMap()).toList();

      await _orderDataSource.createCounterSale(
        clubId: clubId!,
        tipoPago: tipoPago!,
        socioCodigo: socioCodigo.trim().isEmpty ? null : socioCodigo.trim(),
        tipoConsumo: tipoConsumo,
        observaciones: observaciones.trim(),
        items: items,
        combos: combos,
      );

      submitSuccess = true;
      return true;
    } catch (e, st) {
      debugPrint('[COUNTER SALE] submit error');
      debugPrint('[COUNTER SALE] stack: $st');
      if (shouldPresentErrorToUser(e)) {
        submitError = ErrorMapper.publicMessage(e);
      } else {
        submitError = null;
      }
      submitSuccess = false;
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  void resetSale() {
    socioCodigo = '';
    tipoConsumo = 'EN_LUGAR';
    tipoPago = null;
    observaciones = '';
    _productCart.clear();
    _comboCart.clear();
    submitError = null;
    submitSuccess = false;
    notifyListeners();
  }
}
