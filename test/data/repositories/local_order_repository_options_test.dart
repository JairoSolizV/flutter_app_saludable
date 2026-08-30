import 'package:flutter_app_saludable/core/database/database_helper.dart';
import 'package:flutter_app_saludable/data/repositories/local_order_repository.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/entities/order_item_option.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/isolated_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;
  late LocalOrderRepository repo;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dbHelper = await openIsolatedTestDatabase();
    repo = LocalOrderRepository(dbHelper);
  });

  tearDown(() async {
    await closeIsolatedTestDatabase();
  });

  OrderEntity _order(String id, {List<OrderItem> items = const []}) {
    return OrderEntity(
      id: id,
      userId: 'u1',
      clubId: 3,
      membresiaId: 10,
      status: 'pending',
      createdAt: DateTime(2026, 8, 30, 12),
      items: items,
    );
  }

  test('migración v13 conserva pedidos legacy sin opciones', () async {
    final db = await dbHelper.database;
    await db.insert('products', {'id': '7', 'name': 'Batido legacy'});
    await db.insert('orders', {
      'id': 'legacy-1',
      'user_id': 'u1',
      'club_id': 3,
      'membresia_id': 10,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 1,
    });
    await db.insert('order_items', {
      'order_id': 'legacy-1',
      'product_id': '7',
      'quantity': 2,
      'note': '',
    });

    final loaded = await repo.getOrdersByUser('u1');
    expect(loaded, hasLength(1));
    expect(loaded.first.items, hasLength(1));
    expect(loaded.first.items.first.options, isEmpty);
  });

  test('guarda y recarga opciones con ids/nombres/quantity', () async {
    await dbHelper.insert('products', {
      'id': '7',
      'name': 'Batido',
    });

    await repo.createOrder(_order('o1', items: [
      OrderItem(
        orderId: 'o1',
        productId: '7',
        quantity: 2,
        options: const [
          OrderItemOption(
            groupId: 3,
            groupName: 'Sabores',
            groupOrder: 0,
            optionId: 6,
            optionName: 'Frutilla',
            optionOrder: 0,
            quantity: 1,
          ),
          OrderItemOption(
            groupId: 4,
            groupName: 'Consistencia',
            groupOrder: 1,
            optionId: 9,
            optionName: 'Cremoso',
            optionOrder: 0,
            quantity: 1,
          ),
        ],
      ),
    ]));

    final loaded = await repo.getOrdersByUser('u1');
    expect(loaded.first.items.first.quantity, 2);
    final opts = loaded.first.items.first.options;
    expect(opts, hasLength(2));
    expect(opts.first.groupId, 3);
    expect(opts.first.optionId, 6);
    expect(opts.first.optionName, 'Frutilla');
    expect(opts.last.groupName, 'Consistencia');
  });

  test('borrar pedido elimina opciones', () async {
    await dbHelper.insert('products', {'id': '7', 'name': 'Batido'});
    await repo.createOrder(_order('o2', items: [
      OrderItem(
        orderId: 'o2',
        productId: '7',
        quantity: 1,
        options: const [
          OrderItemOption(groupId: 3, optionId: 6, quantity: 1),
        ],
      ),
    ]));
    await repo.deleteOrder('o2');
    final db = await dbHelper.database;
    final optCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM order_item_options'),
        ) ??
        0;
    expect(optCount, 0);
  });

  test('getUnsyncedOrdersForUser incluye opciones para sync', () async {
    await repo.createOrder(_order('o3', items: [
      OrderItem(
        orderId: 'o3',
        productId: '7',
        quantity: 1,
        options: const [
          OrderItemOption(groupId: 3, optionId: 6, quantity: 2),
        ],
      ),
    ]));

    final pending = await repo.getUnsyncedOrdersForUser('u1');
    expect(pending.first.items.first.options.first.quantity, 2);
    expect(pending.first.items.first.options.first.optionId, 6);
  });
}
