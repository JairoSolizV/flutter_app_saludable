/// Snapshot persistible de una opción elegida en un ítem de pedido.
/// Los IDs son la identidad; nombres/orden son snapshot para offline/UI.
class OrderItemOption {
  final int? localId;
  final int? orderItemLocalId;
  final int? groupId;
  final String groupName;
  final int groupOrder;
  final int? optionId;
  final String optionName;
  final int optionOrder;
  final int quantity;

  const OrderItemOption({
    this.localId,
    this.orderItemLocalId,
    this.groupId,
    this.groupName = '',
    this.groupOrder = 0,
    this.optionId,
    this.optionName = '',
    this.optionOrder = 0,
    this.quantity = 1,
  });

  /// Payload sync: solo IDs + cantidad (backend es autoridad).
  Map<String, dynamic> toApiMap() {
    return {
      if (groupId != null) 'grupoId': groupId,
      if (optionId != null) 'opcionId': optionId,
      'cantidad': quantity,
    };
  }

  factory OrderItemOption.fromSelectionFields({
    required int groupId,
    required String groupName,
    int groupOrder = 0,
    required int optionId,
    required String optionName,
    int optionOrder = 0,
    required int quantity,
  }) {
    return OrderItemOption(
      groupId: groupId,
      groupName: groupName,
      groupOrder: groupOrder,
      optionId: optionId,
      optionName: optionName,
      optionOrder: optionOrder,
      quantity: quantity,
    );
  }

  factory OrderItemOption.fromApiJson(Map<String, dynamic> map) {
    return OrderItemOption(
      groupId: _optionalInt(map['grupoId'] ?? map['groupId']),
      groupName: map['grupoNombre']?.toString() ??
          map['groupName']?.toString() ??
          '',
      groupOrder: _optionalInt(map['grupoOrden'] ?? map['groupOrder']) ?? 0,
      optionId: _optionalInt(map['opcionId'] ?? map['optionId']),
      optionName: map['opcionNombre']?.toString() ??
          map['optionName']?.toString() ??
          '',
      optionOrder: _optionalInt(map['opcionOrden'] ?? map['optionOrder']) ?? 0,
      quantity: _optionalInt(map['cantidad'] ?? map['quantity']) ?? 1,
    );
  }

  factory OrderItemOption.fromSqlMap(Map<String, dynamic> map) {
    return OrderItemOption(
      localId: _optionalInt(map['id']),
      orderItemLocalId: _optionalInt(map['order_item_id']),
      groupId: _optionalInt(map['group_id']),
      groupName: map['group_name']?.toString() ?? '',
      groupOrder: _optionalInt(map['group_order']) ?? 0,
      optionId: _optionalInt(map['option_id']),
      optionName: map['option_name']?.toString() ?? '',
      optionOrder: _optionalInt(map['option_order']) ?? 0,
      quantity: _optionalInt(map['quantity']) ?? 1,
    );
  }

  Map<String, dynamic> toSqlMap({required int orderItemId}) {
    return {
      if (localId != null) 'id': localId,
      'order_item_id': orderItemId,
      'group_id': groupId,
      'group_name': groupName,
      'group_order': groupOrder,
      'option_id': optionId,
      'option_name': optionName,
      'option_order': optionOrder,
      'quantity': quantity,
    };
  }

  Map<String, dynamic> toSqlMapForComboComponent({required int componentId}) {
    return {
      if (localId != null) 'id': localId,
      'component_id': componentId,
      'group_id': groupId,
      'group_name': groupName,
      'group_order': groupOrder,
      'option_id': optionId,
      'option_name': optionName,
      'option_order': optionOrder,
      'quantity': quantity,
    };
  }

  factory OrderItemOption.fromComboComponentSqlMap(Map<String, dynamic> map) {
    return OrderItemOption(
      localId: _optionalInt(map['id']),
      groupId: _optionalInt(map['group_id']),
      groupName: map['group_name']?.toString() ?? '',
      groupOrder: _optionalInt(map['group_order']) ?? 0,
      optionId: _optionalInt(map['option_id']),
      optionName: map['option_name']?.toString() ?? '',
      optionOrder: _optionalInt(map['option_order']) ?? 0,
      quantity: _optionalInt(map['quantity']) ?? 1,
    );
  }

  OrderItemOption copyWith({
    int? localId,
    int? orderItemLocalId,
    int? groupId,
    String? groupName,
    int? groupOrder,
    int? optionId,
    String? optionName,
    int? optionOrder,
    int? quantity,
  }) {
    return OrderItemOption(
      localId: localId ?? this.localId,
      orderItemLocalId: orderItemLocalId ?? this.orderItemLocalId,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      groupOrder: groupOrder ?? this.groupOrder,
      optionId: optionId ?? this.optionId,
      optionName: optionName ?? this.optionName,
      optionOrder: optionOrder ?? this.optionOrder,
      quantity: quantity ?? this.quantity,
    );
  }

  bool get hasRequiredIds =>
      groupId != null && groupId! > 0 && optionId != null && optionId! > 0;

  static List<OrderItemOption> listFromApi(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => OrderItemOption.fromApiJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static int? _optionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
