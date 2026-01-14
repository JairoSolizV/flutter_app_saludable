import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';

class LocalOrderRepository implements OrderRepository {
  final DatabaseHelper _dbHelper;

  LocalOrderRepository(this._dbHelper);

  @override
  Future<void> createOrder(OrderEntity order) async {
    final db = await _dbHelper.database;
    
    // Transacción para asegurar consistencia
    await db.transaction((txn) async {
      await txn.insert('orders', order.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      
      for (var item in order.items) {
        await txn.insert('order_items', item.toMap());
      }
    });
  }

  @override
  Future<List<OrderEntity>> getOrdersByUser(String userId) async {
    final db = await _dbHelper.database;
    
    // Obtener pedidos
    final orderMaps = await db.query(
      'orders',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    List<OrderEntity> orders = [];

    for (var orderMap in orderMaps) {
      final orderId = orderMap['id'] as String;
      
      // Obtener items para cada pedido
      // Hacemos un JOIN simple manual o Query separada
      final itemMaps = await db.rawQuery('''
        SELECT oi.*, p.name as product_name 
        FROM order_items oi
        JOIN products p ON oi.product_id = p.id
        WHERE oi.order_id = ?
      ''', [orderId]);

      final items = itemMaps.map((m) => OrderItem.fromMap(m, productName: m['product_name'] as String)).toList();

      orders.add(OrderEntity.fromMap(orderMap, items: items));
    }

    return orders;
  }

  @override
  Future<List<OrderEntity>> getUnsyncedOrders() async {
    final db = await _dbHelper.database;
    final res = await db.query('orders', where: 'is_synced = ?', whereArgs: [0]);
    
    // Nota: Para sincronización completa deberíamos cargar items también, 
    // por brevedad aquí cargamos solo la cabecera o items si es necesario para el backend.
    // Asumiremos que el backend necesita todo.
    
    List<OrderEntity> orders = [];
    for (var row in res) {
        // Cargar items (similar a getOrdersByUser)
         final orderId = row['id'] as String;
         final itemMaps = await db.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
         final items = itemMaps.map((m) => OrderItem.fromMap(m)).toList();
         
         orders.add(OrderEntity.fromMap(row, items: items));
    }
    return orders;
  }

  @override
  Future<void> markAsSynced(String orderId) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}
