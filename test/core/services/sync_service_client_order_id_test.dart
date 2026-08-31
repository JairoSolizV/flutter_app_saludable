import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/services/connectivity_service.dart';
import 'package:flutter_app_saludable/core/services/sync_service.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/repositories/order_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// UUID fijo para tests de POST reales (mismo valor en todos los reintentos).
const kTestClientOrderId = '550e8400-e29b-41d4-a716-446655440000';

class _FakeConnectivity implements ConnectivityService {
  @override
  Stream<bool> get connectionStream => const Stream.empty();

  @override
  Future<bool> checkConnection() async => true;

  @override
  void dispose() {}
}

class _MemRepo implements OrderRepository {
  _MemRepo(this.pending);

  final List<OrderEntity> pending;
  final Set<String> syncedIds = {};
  int markSyncedCalls = 0;
  int deleteCalls = 0;

  @override
  Future<void> createOrder(OrderEntity order) async {}

  @override
  Future<List<OrderEntity>> getOrdersByUser(String userId) async => [];

  @override
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId) async =>
      pending.where((o) => !syncedIds.contains(o.id)).toList();

  @override
  Future<int> countOrphanUnsyncedOrders() async => 0;

  @override
  Future<void> markAsSynced(String orderId) async {
    markSyncedCalls++;
    syncedIds.add(orderId);
  }

  @override
  Future<void> markOrdersAsSynced(List<String> orderIds) async {
    markSyncedCalls++;
    syncedIds.addAll(orderIds);
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {}

  @override
  Future<void> deleteOrder(String orderId) async {
    deleteCalls++;
  }

  @override
  Future<void> deleteOrders(List<String> orderIds) async {
    deleteCalls++;
  }
}

/// Adapter que lanza receive timeout en el primer POST y responde 201 después.
class _TimeoutThenSuccessAdapter implements HttpClientAdapter {
  int postCalls = 0;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'POST' &&
        options.uri.path.contains('/pedidos/con-items')) {
      postCalls++;
      if (postCalls == 1) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return ResponseBody.fromString(
        '{}',
        201,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    }
    return ResponseBody.fromString(
      '{"message":"not stubbed"}',
      404,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Adapter que falla el primer POST con 500 y luego responde 201.
class _RetryThenSuccessAdapter implements HttpClientAdapter {
  int postCalls = 0;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'POST' &&
        options.uri.path.contains('/pedidos/con-items')) {
      postCalls++;
      if (postCalls == 1) {
        return ResponseBody.fromString(
          '{"message":"error temporal"}',
          500,
          headers: {Headers.contentTypeHeader: ['application/json']},
        );
      }
      return ResponseBody.fromString(
        '{}',
        201,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    }
    return ResponseBody.fromString(
      '{"message":"not stubbed"}',
      404,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

OrderEntity _pendingOrder() => OrderEntity(
      id: kTestClientOrderId,
      userId: 'u1',
      clubId: 3,
      membresiaId: 10,
      status: 'pending',
      createdAt: DateTime(2026, 1, 1),
      items: [
        OrderItem(
          orderId: kTestClientOrderId,
          productId: '7',
          quantity: 1,
        ),
      ],
    );

void main() {
  group('SyncService clientOrderId', () {
    test(
        'TimeoutException en primer intento: mismo clientOrderId en retry y luego synced',
        () async {
      final adapter = _TimeoutThenSuccessAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.httpClientAdapter = adapter;
      final remote = OrderRemoteDataSourceImpl(dio);
      final order = _pendingOrder();
      final repo = _MemRepo([order]);
      final sync = SyncService(
        repo,
        _FakeConnectivity(),
        remote,
        SessionOwner()..setUserId('u1'),
      );

      await sync.syncNow();

      expect(repo.markSyncedCalls, 0);
      expect(repo.deleteCalls, 0);
      expect(repo.syncedIds, isEmpty);
      expect(adapter.postCalls, 1);
      final firstClientOrderId =
          (adapter.requests.first.data as Map)['clientOrderId'] as String;
      expect(firstClientOrderId, kTestClientOrderId);

      await sync.syncNow();

      expect(adapter.postCalls, 2);
      final secondClientOrderId =
          (adapter.requests[1].data as Map)['clientOrderId'] as String;
      expect(secondClientOrderId, kTestClientOrderId);
      expect(firstClientOrderId, secondClientOrderId);
      expect(repo.markSyncedCalls, 1);
      expect(repo.syncedIds, {kTestClientOrderId});
      expect(await repo.getUnsyncedOrdersForUser('u1'), isEmpty);

      sync.dispose();
    });

    test('500 en primer intento no marca synced; retry mismo clientOrderId y luego synced',
        () async {
      final adapter = _RetryThenSuccessAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.httpClientAdapter = adapter;
      final remote = OrderRemoteDataSourceImpl(dio);
      final order = _pendingOrder();
      final repo = _MemRepo([order]);
      final sync = SyncService(
        repo,
        _FakeConnectivity(),
        remote,
        SessionOwner()..setUserId('u1'),
      );

      await sync.syncNow();
      expect(repo.markSyncedCalls, 0);
      expect(repo.deleteCalls, 0);
      expect(adapter.postCalls, 1);
      expect(
        (adapter.requests.first.data as Map)['clientOrderId'],
        kTestClientOrderId,
      );

      await sync.syncNow();
      expect(adapter.postCalls, 2);
      expect(
        (adapter.requests[1].data as Map)['clientOrderId'],
        kTestClientOrderId,
      );
      expect(repo.markSyncedCalls, 1);
      expect(repo.syncedIds, {kTestClientOrderId});

      sync.dispose();
    });

    test('400 validación no marca synced ni borra', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.httpClientAdapter = _AlwaysStatusAdapter(400);
      final remote = OrderRemoteDataSourceImpl(dio);
      final repo = _MemRepo([_pendingOrder()]);
      final sync = SyncService(
        repo,
        _FakeConnectivity(),
        remote,
        SessionOwner()..setUserId('u1'),
      );

      await sync.syncNow();
      expect(repo.markSyncedCalls, 0);
      expect(repo.deleteCalls, 0);
      expect(repo.pending, hasLength(1));

      sync.dispose();
    });

    test('409 conflict no marca synced ni borra', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.httpClientAdapter = _AlwaysStatusAdapter(409);
      final remote = OrderRemoteDataSourceImpl(dio);
      final repo = _MemRepo([_pendingOrder()]);
      final sync = SyncService(
        repo,
        _FakeConnectivity(),
        remote,
        SessionOwner()..setUserId('u1'),
      );

      await sync.syncNow();
      expect(repo.markSyncedCalls, 0);
      expect(repo.deleteCalls, 0);
      expect(repo.pending, hasLength(1));

      sync.dispose();
    });
  });
}

class _AlwaysStatusAdapter implements HttpClientAdapter {
  _AlwaysStatusAdapter(this.statusCode);

  final int statusCode;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'message': 'error $statusCode'}),
      statusCode,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}
