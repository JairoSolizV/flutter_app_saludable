class OrderEntity {
  final String id;
  final String userId;
  final int? clubId; // ID del club donde se hace el pedido
  final int? membresiaId; // ID de la membresía del socio
  final double total;
  final String status; // 'pending', 'preparing', 'ready', 'completed'
  final DateTime createdAt;
  final bool isSynced;
  final List<OrderItem> items;

  OrderEntity({
    required this.id,
    required this.userId,
    this.clubId,
    this.membresiaId,
    required this.total,
    required this.status,
    required this.createdAt,
    this.isSynced = false,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'club_id': clubId,
      'membresia_id': membresiaId,
      'total': total,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory OrderEntity.fromMap(Map<String, dynamic> map, {List<OrderItem> items = const []}) {
    return OrderEntity(
      id: map['id'],
      userId: map['user_id'],
      clubId: map['club_id'],
      membresiaId: map['membresia_id'],
      total: map['total'],
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
      isSynced: map['is_synced'] == 1,
      items: items,
    );
  }
}

class OrderItem {
  final String? id; // ID DB local (autoincrement)
  final String orderId;
  final String productId;
  final int quantity;
  final double price;
  final String productName; // Desnormalizado para facil visualización offline

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.price,
    this.productName = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
      // 'product_name' no se guarda en tabla order_items normalizada, pero útil si se quiere desnormalizar. 
      // Por ahora mantenemos simple.
    };
  }
  
  factory OrderItem.fromMap(Map<String, dynamic> map, {String productName = ''}) {
    return OrderItem(
      id: map['id'].toString(),
      orderId: map['order_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      price: map['price'],
      productName: productName,
    );
  }
}
