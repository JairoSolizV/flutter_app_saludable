import '../../domain/entities/order_item_option.dart';

/// Formateo de opciones de pedido para carrito e historial (snapshot local/API).
class OrderItemOptionsDisplay {
  OrderItemOptionsDisplay._();

  /// Resumen compacto: `Frutilla · Cremoso` o `Frutilla ×2`.
  static String compactSummary(List<OrderItemOption> options) {
    if (options.isEmpty) return '';
    final sorted = _sorted(options);
    return sorted.map(_optionLabel).join(' · ');
  }

  /// Líneas por grupo: `Sabores: Frutilla`, `Consistencia: Cremoso ×2`.
  static List<String> groupLines(List<OrderItemOption> options) {
    if (options.isEmpty) return const [];
    final sorted = _sorted(options);
    final byGroup = <String, List<OrderItemOption>>{};
    for (final opt in sorted) {
      final key = opt.groupName.isNotEmpty ? opt.groupName : 'Opciones';
      byGroup.putIfAbsent(key, () => []).add(opt);
    }
    final lines = <String>[];
    for (final entry in byGroup.entries) {
      final labels = entry.value.map(_optionLabel).join(', ');
      lines.add('${entry.key}: $labels');
    }
    return lines;
  }

  /// Bullets para HOST: `- Sabores: Frutilla`.
  static List<String> hostBulletLines(List<OrderItemOption> options) {
    return groupLines(options)
        .map((line) => line.startsWith('-') ? line : '- $line')
        .toList();
  }

  static List<OrderItemOption> _sorted(List<OrderItemOption> options) {
    final copy = [...options];
    copy.sort((a, b) {
      final byGroupOrder = a.groupOrder.compareTo(b.groupOrder);
      if (byGroupOrder != 0) return byGroupOrder;
      final byGroupName = a.groupName.compareTo(b.groupName);
      if (byGroupName != 0) return byGroupName;
      final byOptionOrder = a.optionOrder.compareTo(b.optionOrder);
      if (byOptionOrder != 0) return byOptionOrder;
      return (a.optionId ?? 0).compareTo(b.optionId ?? 0);
    });
    return copy;
  }

  static String _optionLabel(OrderItemOption opt) {
    if (opt.quantity > 1) {
      return '${opt.optionName} ×${opt.quantity}';
    }
    return opt.optionName;
  }

  /// Parsea `opciones` del item de historial remoto o lista ya materializada.
  static List<OrderItemOption> parseFromHistoryItem(Map<String, dynamic> item) {
    final raw = item['opciones'] ?? item['options'];
    if (raw == null) return const [];
    if (raw is List<OrderItemOption>) return raw;
    if (raw is List) {
      if (raw.isNotEmpty && raw.first is OrderItemOption) {
        return raw.cast<OrderItemOption>();
      }
      return OrderItemOption.listFromApi(raw);
    }
    return const [];
  }
}
