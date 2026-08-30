import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/orders/order_submit_outcome.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/core/services/connectivity_service.dart';
import 'package:flutter_app_saludable/core/services/sync_service.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/repositories/order_repository.dart';
import 'package:flutter_app_saludable/presentation/providers/order_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemOrderRepo implements OrderRepository {
  final List<OrderEntity> stored = [];

  @override
  Future<void> createOrder(OrderEntity order) async {
    stored.add(order);
  }

  @override
  Future<List<OrderEntity>> getOrdersByUser(String userId) async =>
      stored.where((o) => o.userId == userId).toList();

  @override
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId) async =>
      stored.where((o) => o.userId == userId && !o.isSynced).toList();

  @override
  Future<int> countOrphanUnsyncedOrders() async => 0;

  @override
  Future<void> markAsSynced(String orderId) async {
    final i = stored.indexWhere((o) => o.id == orderId);
    if (i < 0) return;
    final o = stored[i];
    stored[i] = OrderEntity(
      id: o.id,
      userId: o.userId,
      clubId: o.clubId,
      membresiaId: o.membresiaId,
      tipoConsumo: o.tipoConsumo,
      observaciones: o.observaciones,
      status: o.status,
      createdAt: o.createdAt,
      isSynced: true,
      items: o.items,
    );
  }

  @override
  Future<void> markOrdersAsSynced(List<String> orderIds) async {
    for (final id in orderIds) {
      await markAsSynced(id);
    }
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {}

  @override
  Future<void> deleteOrder(String orderId) async {
    stored.removeWhere((o) => o.id == orderId);
  }

  @override
  Future<void> deleteOrders(List<String> orderIds) async {
    stored.removeWhere((o) => orderIds.contains(o.id));
  }
}

class _FakeRemote implements OrderRemoteDataSource {
  final List<String> sentIds = [];

  @override
  Future<void> sendOrder(OrderEntity order, {required List<OrderItem> items, required List<OrderCombo> combos}) async {
    sentIds.add(order.id);
  }

  @override
  Future<void> createCounterSale({
    required int clubId,
    required String tipoPago,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId) async =>
      [];

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(int clubId,
          {int page = 0,
          int size = 20,
          String? estado,
          String? desde,
          String? hasta}) =>
      throw UnimplementedError();

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(int membresiaId,
          {int page = 0,
          int size = 20,
          String? estado,
          String? desde,
          String? hasta}) =>
      throw UnimplementedError();

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus,
          {int? estimatedTime}) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() async => [];
}

OrderEntity _order(String id) {
  return OrderEntity(
    id: id,
    userId: 'u1',
    clubId: 3,
    membresiaId: 10,
    status: 'pending',
    createdAt: DateTime(2026, 8, 30),
    isSynced: false,
    items: [
      OrderItem(orderId: id, productId: '7', quantity: 1),
    ],
  );
}

void main() {
  test('createOrder offline retorna localPending y no envía remoto', () async {
    final repo = _MemOrderRepo();
    final remote = _FakeRemote();
    final owner = SessionOwner()..setUserId('u1');
    final provider = OrderProvider(
      repo,
      ConnectivityService.forTest(checkConnection: () async => false),
      SyncService(
        repo,
        ConnectivityService.forTest(checkConnection: () async => false),
        remote,
        owner,
      ),
    );

    final outcome = await provider.createOrder(_order('id-offline-a'));

    expect(outcome, OrderSubmitOutcome.localPending);
    expect(remote.sentIds, isEmpty);
    expect(repo.stored.single.id, 'id-offline-a');
  });

  test('createOrder online con sync 201 retorna remoteSynced', () async {
    final repo = _MemOrderRepo();
    final remote = _FakeRemote();
    final owner = SessionOwner()..setUserId('u1');
    final provider = OrderProvider(
      repo,
      ConnectivityService.forTest(checkConnection: () async => true),
      SyncService(
        repo,
        ConnectivityService.forTest(checkConnection: () async => true),
        remote,
        owner,
      ),
    );

    final outcome = await provider.createOrder(_order('id-online-b'));

    expect(outcome, OrderSubmitOutcome.remoteSynced);
    expect(remote.sentIds, ['id-online-b']);
    expect(await repo.getUnsyncedOrdersForUser('u1'), isEmpty);
  });

  test('sync usa el mismo UUID persistido', () async {
    final repo = _MemOrderRepo();
    final remote = _FakeRemote();
    final owner = SessionOwner()..setUserId('u1');
    await repo.createOrder(_order('uuid-fixed-123'));

    final sync = SyncService(
      repo,
      ConnectivityService.forTest(checkConnection: () async => true),
      remote,
      owner,
    );
    await sync.syncNow();

    expect(remote.sentIds, ['uuid-fixed-123']);
  });
}
