import '../../domain/entities/order_combo.dart';
import '../../domain/entities/order_item_option.dart';
import 'order_item_options_display.dart';

/// Helpers para renderizar historial con combos modernos vs legacy.
class OrderComboHistoryDisplay {
  OrderComboHistoryDisplay._();

  /// Items sueltos: excluye componentes duplicados de combos modernos.
  static List<Map<String, dynamic>> standaloneItems(
    Map<String, dynamic> order,
  ) {
    final items = _rawItems(order);
    if (items.isEmpty) return const [];

    final combos = PedidoComboSnapshot.listFromOrder(order);
    if (combos.isNotEmpty) {
      return items.where((item) {
        final pedidoComboId = item['pedidoComboId'] ?? item['pedido_combo_id'];
        return pedidoComboId == null;
      }).toList();
    }

    return items;
  }

  /// Items legacy expandidos (comboId por línea, sin combos[]).
  static List<Map<String, dynamic>> legacyComboItems(
    Map<String, dynamic> order,
  ) {
    if (PedidoComboSnapshot.listFromOrder(order).isNotEmpty) {
      return const [];
    }
    return _rawItems(order).where((item) {
      final comboId = item['comboId'] ?? item['combo_id'];
      return comboId != null;
    }).toList();
  }

  static List<Map<String, dynamic>> _rawItems(Map<String, dynamic> order) {
    final raw = order['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Líneas de opciones para un componente de combo en historial.
  static List<String> componentOptionLines(Map<String, dynamic> item) {
    return OrderItemOptionsDisplay.groupLines(
      OrderItemOptionsDisplay.parseFromHistoryItem(item),
    );
  }

  static List<String> componentOptionLinesFromSnapshot(
    PedidoComboItemSnapshot item,
  ) {
    return OrderItemOptionsDisplay.groupLines(item.options);
  }
}
