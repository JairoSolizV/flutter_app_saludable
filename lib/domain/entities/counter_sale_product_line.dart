import 'product.dart';
import 'product_option_selection.dart';

/// Línea de carrito mostrador: producto suelto con configuración opcional.
class CounterSaleProductLine {
  final Product product;
  final List<ProductOptionSelection> selections;
  int quantity;
  String note;

  CounterSaleProductLine({
    required this.product,
    this.selections = const [],
    this.quantity = 1,
    this.note = '',
  });

  String get configKey =>
      ProductOptionSelection.cartKey(product.id, selections);

  double get unitPrice => product.effectivePrice;

  int get pointsPerUnit => product.puntosValor;

  double get subtotal => unitPrice * quantity;

  int get totalPoints => pointsPerUnit * quantity;

  String get optionsSummary {
    if (selections.isEmpty) return '';
    return selections.map((s) => s.summaryLabel).join(' · ');
  }

  CounterSaleProductLine copyWith({
    Product? product,
    List<ProductOptionSelection>? selections,
    int? quantity,
    String? note,
  }) {
    return CounterSaleProductLine(
      product: product ?? this.product,
      selections: selections ?? this.selections,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }
}
