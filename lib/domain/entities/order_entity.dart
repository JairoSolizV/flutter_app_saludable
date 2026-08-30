import 'order_item_option.dart';
import 'order_combo.dart';

export 'order_item_option.dart';
export 'order_combo.dart';

class OrderEntity {
  final String id;
  final String userId;
  final int? clubId; // ID del club donde se hace el pedido
  final int? membresiaId; // ID de la membresía del socio
  final String? tipoConsumo; // 'EN_LUGAR' o 'PARA_LLEVAR'
  final String? observaciones; // Nota general del pedido
  final String status; // 'pending', 'preparing', 'ready', 'completed'
  final DateTime createdAt;
  final bool isSynced;
  final int? tiempoEstimadoMinutos; // min
  final List<OrderItem> items;
  final List<OrderCombo> combos;

  OrderEntity({
    required this.id,
    required this.userId,
    this.clubId,
    this.membresiaId,
    this.tipoConsumo,
    this.observaciones,
    required this.status,
    required this.createdAt,
    this.isSynced = false,
    this.tiempoEstimadoMinutos,
    this.items = const [],
    this.combos = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'club_id': clubId,
      'membresia_id': membresiaId,
      'tipo_consumo': tipoConsumo,
      'observaciones': observaciones,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'tiempoEstimadoMinutos': tiempoEstimadoMinutos,
    };
  }

  factory OrderEntity.fromMap(
    Map<String, dynamic> map, {
    List<OrderItem> items = const [],
    List<OrderCombo> combos = const [],
  }) {
    return OrderEntity(
      id: map['id'],
      userId: map['user_id'],
      clubId: map['club_id'],
      membresiaId: map['membresia_id'],
      tipoConsumo: map['tipo_consumo'],
      observaciones: map['observaciones'],
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
      isSynced: map['is_synced'] == 1,
      tiempoEstimadoMinutos: map['tiempoEstimadoMinutos'],
      items: items,
      combos: combos,
    );
  }
}

class OrderItem {
  final String? id; // ID DB local (autoincrement)
  final String orderId;
  final String productId;
  final int quantity;
  final String note; // Comentario humano — no fuente de verdad de opciones
  final String productName; // Desnormalizado para facil visualización offline
  final int? comboId; // ID del combo origen (null si es producto suelto)
  final List<OrderItemOption> options;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    this.note = '',
    this.productName = '',
    this.comboId,
    this.options = const [],
  });

  /// Identidad estable de línea (misma semántica que cartKey del carrito).
  static String lineKey({
    required String productId,
    required List<OrderItemOption> options,
    int? comboId,
  }) {
    if (comboId != null) return '$productId@combo:$comboId';
    if (options.isEmpty) return productId;
    final parts = [...options]
      ..sort((a, b) {
        final g = (a.groupId ?? 0).compareTo(b.groupId ?? 0);
        if (g != 0) return g;
        return (a.optionId ?? 0).compareTo(b.optionId ?? 0);
      });
    final sig = parts
        .map((o) => '${o.groupId}:${o.optionId}:${o.quantity}')
        .join('|');
    return '$productId#$sig';
  }

  String get lineKeyValue => lineKey(
        productId: productId,
        options: options,
        comboId: comboId,
      );

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'note': note,
      if (comboId != null) 'combo_id': comboId,
    };
  }

  factory OrderItem.fromMap(
    Map<String, dynamic> map, {
    String productName = '',
    List<OrderItemOption> options = const [],
  }) {
    return OrderItem(
      id: map['id']?.toString(),
      orderId: map['order_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      note: map['note'] ?? '',
      productName: productName,
      comboId: _optionalInt(map['combo_id']),
      options: options,
    );
  }

  static int? _optionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
