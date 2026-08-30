import 'product_option_selection.dart';
import 'order_combo.dart';

/// Componente configurado dentro de un combo en el carrito SOCIO.
class ComboCartComponent {
  final int productId;
  final String productName;
  final List<ProductOptionSelection> selections;

  const ComboCartComponent({
    required this.productId,
    required this.productName,
    this.selections = const [],
  });

  ComboCartComponent copyWith({
    int? productId,
    String? productName,
    List<ProductOptionSelection>? selections,
  }) {
    return ComboCartComponent(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      selections: selections ?? this.selections,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ComboCartComponent &&
      other.productId == productId &&
      _selectionsEqual(other.selections, selections);

  @override
  int get hashCode => Object.hash(productId, _selectionsHash(selections));

  static bool _selectionsEqual(
    List<ProductOptionSelection> a,
    List<ProductOptionSelection> b,
  ) {
    if (a.length != b.length) return false;
    final sa = _sortedSelections(a);
    final sb = _sortedSelections(b);
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }

  static int _selectionsHash(List<ProductOptionSelection> sels) {
    final sorted = _sortedSelections(sels);
    return Object.hashAll(sorted.map((s) => s.signaturePart));
  }

  static List<ProductOptionSelection> _sortedSelections(
    List<ProductOptionSelection> sels,
  ) {
    final copy = [...sels]
      ..sort((a, b) {
        final g = a.groupId.compareTo(b.groupId);
        if (g != 0) return g;
        return a.optionId.compareTo(b.optionId);
      });
    return copy;
  }
}

/// Línea de carrito: un combo con configuración concreta de componentes.
class ComboCartItem {
  final int comboId;
  final String comboName;
  final double price;
  final int points;
  final int quantity;
  final List<ComboCartComponent> components;

  const ComboCartItem({
    required this.comboId,
    required this.comboName,
    required this.price,
    required this.points,
    required this.quantity,
    required this.components,
  });

  bool get hasConfiguredPrice => price > 0;

  double get lineTotal => price * quantity;

  String get configKey => identityKey(comboId: comboId, components: components);

  ComboCartItem copyWith({int? quantity}) {
    return ComboCartItem(
      comboId: comboId,
      comboName: comboName,
      price: price,
      points: points,
      quantity: quantity ?? this.quantity,
      components: components,
    );
  }

  /// Identidad estable: combo + configuración normalizada de componentes.
  static String identityKey({
    required int comboId,
    required List<ComboCartComponent> components,
  }) {
    final parts = components.map((c) {
      final opts = ComboCartComponent._sortedSelections(c.selections);
      final sig = opts.map((s) => s.signaturePart).join('|');
      return '${c.productId}:$sig';
    }).toList()
      ..sort();
    return 'combo:$comboId#${parts.join(';')}';
  }

  Map<String, dynamic> toCounterSaleApiMap() {
    return {
      'comboId': comboId,
      'cantidad': quantity,
      'componentes': components
          .map(
            (c) => {
              'productoId': c.productId,
              'opciones': c.selections
                  .map((s) => s.toOrderItemOption().toApiMap())
                  .toList(),
            },
          )
          .toList(),
    };
  }

  /// Líneas indentadas para ticket mostrador (sin precios por componente).
  List<String> ticketComponentLines() {
    return components.map((c) {
      final opts = c.selections.map((s) => s.summaryLabel).join(' · ');
      if (opts.isEmpty) return c.productName;
      return '${c.productName}\n  $opts';
    }).toList();
  }

  OrderCombo toOrderCombo(String orderId) {
    return OrderCombo(
      orderId: orderId,
      comboId: comboId,
      comboName: comboName,
      quantity: quantity,
      priceSnapshot: price,
      pointsSnapshot: points,
      components: components
          .map(
            (c) => OrderComboComponent(
              productId: c.productId,
              productName: c.productName,
              options: c.selections.map((s) => s.toOrderItemOption()).toList(),
            ),
          )
          .toList(),
    );
  }

  /// Resumen compacto para checkout: una línea por componente.
  List<String> componentSummaryLines() {
    return components.map((c) {
      final opts = c.selections.map((s) => s.summaryLabel).join(' · ');
      if (opts.isEmpty) return c.productName;
      return '${c.productName}: $opts';
    }).toList();
  }

  String get componentsSummary => componentSummaryLines().join('\n');
}
