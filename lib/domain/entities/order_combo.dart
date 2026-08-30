import 'order_item_option.dart';

/// Componente de combo persistido localmente / enviado al backend.
class OrderComboComponent {
  final String? localId;
  final int productId;
  final String productName;
  final List<OrderItemOption> options;

  const OrderComboComponent({
    this.localId,
    required this.productId,
    required this.productName,
    this.options = const [],
  });

  Map<String, dynamic> toApiComponentMap() {
    return {
      'productoId': productId,
      'opciones': options.map((o) => o.toApiMap()).toList(),
    };
  }
}

/// Combo en un pedido (carrito offline → request combos[]).
class OrderCombo {
  final String? localId;
  final String orderId;
  final int comboId;
  final String comboName;
  final int quantity;
  final double priceSnapshot;
  final int pointsSnapshot;
  final List<OrderComboComponent> components;

  const OrderCombo({
    this.localId,
    required this.orderId,
    required this.comboId,
    required this.comboName,
    required this.quantity,
    required this.priceSnapshot,
    required this.pointsSnapshot,
    this.components = const [],
  });

  Map<String, dynamic> toApiMap() {
    return {
      'comboId': comboId,
      'cantidad': quantity,
      'componentes': components.map((c) => c.toApiComponentMap()).toList(),
    };
  }
}

/// Combo devuelto por el backend en PedidoDTO.combos[] (historial).
class PedidoComboSnapshot {
  final int? pedidoComboId;
  final int? comboId;
  final String comboName;
  final int quantity;
  final double precioUnitario;
  final double subtotal;
  final int puntosValor;
  final List<PedidoComboItemSnapshot> items;

  const PedidoComboSnapshot({
    this.pedidoComboId,
    this.comboId,
    required this.comboName,
    required this.quantity,
    required this.precioUnitario,
    required this.subtotal,
    required this.puntosValor,
    this.items = const [],
  });

  factory PedidoComboSnapshot.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return PedidoComboSnapshot(
      pedidoComboId: _optionalInt(map['pedidoComboId']),
      comboId: _optionalInt(map['comboId']),
      comboName: map['comboNombre']?.toString() ??
          map['comboName']?.toString() ??
          '',
      quantity: _optionalInt(map['cantidad']) ?? 1,
      precioUnitario: _parseDouble(map['precioUnitario']),
      subtotal: _parseDouble(map['subtotal']),
      puntosValor: _optionalInt(map['puntosValor']) ?? 0,
      items: rawItems
          .whereType<Map>()
          .map((e) => PedidoComboItemSnapshot.fromMap(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
    );
  }

  static List<PedidoComboSnapshot> listFromOrder(Map<String, dynamic> order) {
    final raw = order['combos'];
    if (raw is! List || raw.isEmpty) return const [];
    return raw
        .whereType<Map>()
        .map((e) => PedidoComboSnapshot.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static int? _optionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

/// Item componente dentro de PedidoComboSnapshot (preparación / historial).
class PedidoComboItemSnapshot {
  final int? productoId;
  final String productoNombre;
  final int cantidad;
  final String? nota;
  final List<OrderItemOption> options;

  const PedidoComboItemSnapshot({
    this.productoId,
    required this.productoNombre,
    required this.cantidad,
    this.nota,
    this.options = const [],
  });

  factory PedidoComboItemSnapshot.fromMap(Map<String, dynamic> map) {
    return PedidoComboItemSnapshot(
      productoId: PedidoComboSnapshot._optionalInt(map['productoId']),
      productoNombre: map['productoNombre']?.toString() ?? '',
      cantidad: PedidoComboSnapshot._optionalInt(map['cantidad']) ?? 1,
      nota: map['nota']?.toString(),
      options: OrderItemOption.listFromApi(map['opciones'] ?? map['options']),
    );
  }
}
