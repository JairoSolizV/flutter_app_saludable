import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/order_item_option.dart';
import '../../domain/repositories/order_repository.dart';

typedef DatabaseGetter = Future<Database> Function();

/// Repositorio local de pedidos. Lecturas de items en batch (sin N+1).
class LocalOrderRepository implements OrderRepository {
  LocalOrderRepository(DatabaseHelper dbHelper)
      : _getDatabase = (() => dbHelper.database);

  /// Constructor de test: permite SQLite in-memory e instrumentación.
  @visibleForTesting
  LocalOrderRepository.test(this._getDatabase);

  final DatabaseGetter _getDatabase;

  /// SQLite default variable limit is 999; leave margin for other bind args.
  static const int sqliteInChunkSize = 500;

  /// Contador de llamadas SQL (tests N+1). No usar en producción.
  @visibleForTesting
  int sqlCallCount = 0;

  @visibleForTesting
  void resetSqlCallCount() => sqlCallCount = 0;

  void _trackSql() => sqlCallCount++;

  Future<Database> get _db async => _getDatabase();

  @override
  Future<void> createOrder(OrderEntity order) async {
    final owner = order.userId.trim();
    if (owner.isEmpty) {
      throw ArgumentError(
        'No se puede crear un pedido offline sin userId de propietario',
      );
    }

    final db = await _db;
    _trackSql();
    await db.transaction((txn) async {
      await txn.insert(
        'orders',
        order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final item in order.items) {
        final itemId = await txn.insert('order_items', item.toMap());
        for (final opt in item.options) {
          await txn.insert(
            'order_item_options',
            opt.toSqlMap(orderItemId: itemId),
          );
        }
      }
    });
  }

  @override
  Future<List<OrderEntity>> getOrdersByUser(String userId) async {
    final owner = userId.trim();
    if (owner.isEmpty) return [];

    final db = await _db;
    _trackSql();
    final orderMaps = await db.query(
      'orders',
      where: 'user_id = ?',
      whereArgs: [owner],
      orderBy: 'created_at DESC',
    );

    return _attachItems(
      db,
      orderMaps,
      joinProducts: true,
    );
  }

  @override
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId) async {
    final owner = userId.trim();
    if (owner.isEmpty) return [];

    final db = await _db;

    _trackSql();
    final res = await db.query(
      'orders',
      where:
          'is_synced = ? AND user_id = ? AND user_id IS NOT NULL AND TRIM(user_id) != ?',
      whereArgs: [0, owner, ''],
      orderBy: 'created_at ASC',
    );

    final orphans = await countOrphanUnsyncedOrders();
    if (orphans > 0) {
      logDebug(
        '[Orders] $orphans pedido(s) offline huérfano(s) en cuarentena (no sync)',
      );
    }

    // Sync no requiere nombre de producto; conservar items aunque falte catálogo.
    return _attachItems(db, res, joinProducts: false);
  }

  @override
  Future<int> countOrphanUnsyncedOrders() async {
    final db = await _db;
    _trackSql();
    final res = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM orders
      WHERE is_synced = 0
        AND (user_id IS NULL OR TRIM(user_id) = '')
    ''');
    final value = res.first['c'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  @override
  Future<void> markAsSynced(String orderId) async {
    await markOrdersAsSynced([orderId]);
  }

  @override
  Future<void> markOrdersAsSynced(List<String> orderIds) async {
    final ids = orderIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) return;

    final db = await _db;
    _trackSql();
    await db.transaction((txn) async {
      for (final chunk in _chunks(ids, sqliteInChunkSize)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        await txn.rawUpdate(
          'UPDATE orders SET is_synced = 1 WHERE id IN ($placeholders)',
          chunk,
        );
      }
    });
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    final db = await _db;
    _trackSql();
    await db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    await deleteOrders([orderId]);
  }

  @override
  Future<void> deleteOrders(List<String> orderIds) async {
    final ids = orderIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) return;

    final db = await _db;
    _trackSql();
    await db.transaction((txn) async {
      for (final chunk in _chunks(ids, sqliteInChunkSize)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final itemRows = await txn.rawQuery(
          'SELECT id FROM order_items WHERE order_id IN ($placeholders)',
          chunk,
        );
        final itemIds = itemRows
            .map((r) => r['id'])
            .whereType<int>()
            .toList();
        if (itemIds.isNotEmpty) {
          final itemPh = List.filled(itemIds.length, '?').join(',');
          await txn.rawDelete(
            'DELETE FROM order_item_options WHERE order_item_id IN ($itemPh)',
            itemIds,
          );
        }
        await txn.rawDelete(
          'DELETE FROM order_items WHERE order_id IN ($placeholders)',
          chunk,
        );
        await txn.rawDelete(
          'DELETE FROM orders WHERE id IN ($placeholders)',
          chunk,
        );
      }
    });
  }

  /// Carga items de todas las órdenes en consultas batch (chunks), sin N+1.
  ///
  /// [joinProducts]: si true, INNER JOIN products (mismo comportamiento previo
  /// de getOrdersByUser: items sin producto en catálogo local no aparecen).
  Future<List<OrderEntity>> _attachItems(
    Database db,
    List<Map<String, Object?>> orderRows, {
    required bool joinProducts,
  }) async {
    if (orderRows.isEmpty) return [];

    final orderIds = <String>[];
    for (final row in orderRows) {
      final id = row['id']?.toString();
      if (id != null && id.isNotEmpty) orderIds.add(id);
    }

    final itemsByOrderId = <String, List<OrderItem>>{
      for (final id in orderIds) id: <OrderItem>[],
    };
    final optionsByItemId = <int, List<OrderItemOption>>{};

    for (final chunk in _chunks(orderIds, sqliteInChunkSize)) {
      if (chunk.isEmpty) continue;
      final placeholders = List.filled(chunk.length, '?').join(',');
      _trackSql();

      final List<Map<String, Object?>> itemRows;
      if (joinProducts) {
        itemRows = await db.rawQuery(
          '''
          SELECT oi.*, p.name AS product_name
          FROM order_items oi
          INNER JOIN products p ON oi.product_id = p.id
          WHERE oi.order_id IN ($placeholders)
          ORDER BY oi.order_id ASC, oi.id ASC
          ''',
          chunk,
        );
      } else {
        itemRows = await db.rawQuery(
          '''
          SELECT oi.*
          FROM order_items oi
          WHERE oi.order_id IN ($placeholders)
          ORDER BY oi.order_id ASC, oi.id ASC
          ''',
          chunk,
        );
      }

      final itemIds = itemRows
          .map((m) => _optionalInt(m['id']))
          .whereType<int>()
          .toList();
      if (itemIds.isNotEmpty) {
        for (final idChunk in _chunks(itemIds, sqliteInChunkSize)) {
          final idPh = List.filled(idChunk.length, '?').join(',');
          _trackSql();
          final optRows = await db.rawQuery(
            '''
            SELECT *
            FROM order_item_options
            WHERE order_item_id IN ($idPh)
            ORDER BY order_item_id ASC, group_order ASC, option_order ASC
            ''',
            idChunk,
          );
          for (final row in optRows) {
            final oid = _optionalInt(row['order_item_id']);
            if (oid == null) continue;
            optionsByItemId.putIfAbsent(oid, () => []).add(
                  OrderItemOption.fromSqlMap(row),
                );
          }
        }
      }

      for (final m in itemRows) {
        final orderId = m['order_id']?.toString();
        if (orderId == null) continue;
        final list = itemsByOrderId[orderId];
        if (list == null) continue;
        final itemId = _optionalInt(m['id']);
        list.add(
          OrderItem.fromMap(
            m,
            productName: (m['product_name'] as String?) ?? '',
            options: itemId != null ? (optionsByItemId[itemId] ?? const []) : const [],
          ),
        );
      }
    }

    return [
      for (final row in orderRows)
        OrderEntity.fromMap(
          row,
          items: itemsByOrderId[row['id']?.toString()] ?? const [],
        ),
    ];
  }

  static Iterable<List<T>> _chunks<T>(List<T> source, int size) sync* {
    if (source.isEmpty) return;
    for (var i = 0; i < source.length; i += size) {
      final end = (i + size < source.length) ? i + size : source.length;
      yield source.sublist(i, end);
    }
  }

  static int? _optionalInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
