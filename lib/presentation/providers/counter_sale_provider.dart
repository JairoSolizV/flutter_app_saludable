import 'package:flutter/foundation.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/constants/counter_sale_payment_types.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';

import '../../data/datasources/remote/order_remote_data_source.dart';
import '../../data/datasources/remote/product_remote_data_source.dart';
import '../../data/datasources/remote/combo_remote_data_source.dart';
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
  final Map<String, CounterSaleProductLine> _productCart = {};

  List<Product> get generalProducts =>
      _products.where((p) => p.tipo == 'GLOBAL').toList();
  List<Product> get clubSpecialties =>
      _products.where((p) => p.tipo == 'LOCAL').toList();
  List<CounterSaleProductLine> get cartLines => _productCart.values.toList();
  int get totalItems =>
      _productCart.values.fold(0, (sum, line) => sum + line.quantity);
  double get totalBs =>
      _productCart.values.fold(0.0, (sum, line) => sum + line.subtotal);
  int get totalPuntos =>
      _productCart.values.fold(0, (sum, line) => sum + line.totalPoints);
  bool get canSubmit =>
      _productCart.isNotEmpty &&
      !isSubmitting &&
      tipoPago != null &&
      CounterSalePaymentTypes.backendValues.contains(tipoPago);

  /// Combos deshabilitados hasta HOST-COUNTER-002.
  bool get combosEnabled => false;

  @override
  Future<void> clearSessionState() async {
    clubId = null;
    hubId = null;
    socioCodigo = '';
    tipoConsumo = 'EN_LUGAR';
    tipoPago = null;
    observaciones = '';
    _products = [];
    _productCart.clear();
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
      // Combos: catálogo no cargado en COUNTER-001 (HOST-COUNTER-002).
      final _ = _comboDataSource;
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

  Future<bool> submitCounterSale() async {
    if (clubId == null) {
      submitError = 'No se encontró club para registrar la venta.';
      notifyListeners();
      return false;
    }
    if (_productCart.isEmpty) {
      submitError = 'Debes agregar al menos un producto.';
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

      await _orderDataSource.createCounterSale(
        clubId: clubId!,
        tipoPago: tipoPago!,
        socioCodigo: socioCodigo.trim().isEmpty ? null : socioCodigo.trim(),
        tipoConsumo: tipoConsumo,
        observaciones: observaciones.trim(),
        items: items,
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
    submitError = null;
    submitSuccess = false;
    notifyListeners();
  }
}
