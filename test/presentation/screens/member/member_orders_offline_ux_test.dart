import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/orders/order_offline_messages.dart';
import 'package:flutter_app_saludable/core/orders/order_sync_status.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/data/datasources/remote/membresia_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/attendance.dart';
import 'package:flutter_app_saludable/domain/entities/arbol_referidos.dart';
import 'package:flutter_app_saludable/domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/entities/order_item_option.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/domain/repositories/order_repository.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/member/member_orders_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/fake_user_repository.dart';

class _FakeMembresiaDs implements MembresiaRemoteDataSource {
  Object? getMembresiasError;

  @override
  Future<List<ClubMembership>> getMembresiasPorUsuario(int usuarioId) async {
    if (getMembresiasError != null) throw getMembresiasError!;
    return [
        ClubMembership(
          id: 10,
          usuarioId: usuarioId,
          usuarioNombre: 'Socio',
          clubId: 3,
          clubNombre: 'Club Test',
          nivelId: 1,
          nivelNombre: 'Socio',
          numeroSocio: '001',
          puntosAcumulados: 0,
          fechaRegistro: '2026-01-01',
          estado: 'ACTIVO',
        ),
      ];
  }

  @override
  Future<void> activarSocio({
    required int clubId,
    required String activationPayload,
    int? referidoPorMembresiaId,
    String? comoConocio,
    required bool esClientePreferenteODistribuidor,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> crearMembresia({
    required int usuarioId,
    required int clubId,
    int? nivelId,
    Map<String, dynamic>? extraData,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Attendance>> getAsistencias(int membresiaId) =>
      throw UnimplementedError();

  @override
  Future<AsistenciaResponse> registrarAsistencia({
    required int membresiaId,
    required int clubId,
    required double latitud,
    required double longitud,
  }) =>
      throw UnimplementedError();

  @override
  Future<Attendance> registrarAsistenciaManual({
    required int membresiaId,
    String? fecha,
    String? nota,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getEstadoCombo(int membresiaId) =>
      throw UnimplementedError();

  @override
  Future<List<ClubMembership>> buscarMiembrosGlobal({String? query}) =>
      throw UnimplementedError();

  @override
  Future<PagedResult<ClubMembership>> buscarMiembrosGlobalPage({
    String? query,
    int page = 0,
    int size = 20,
  }) =>
      throw UnimplementedError();

  @override
  Future<ArbolReferidos> getArbolReferidos(int membresiaId) =>
      throw UnimplementedError();
}

class _FakeOrderRemote implements OrderRemoteDataSource {
  Object? pageError;

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(
    int membresiaId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) async {
    if (pageError != null) throw pageError!;
    return PagedResult<Map<String, dynamic>>.empty(page: page, size: size);
  }

  @override
  Future<void> sendOrder(OrderEntity order, {required List<OrderItem> items, required List<OrderCombo> combos}) async {}

  @override
  Future<void> createCounterSale({
    required int clubId,
    required String tipoPago,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> combos = const [],
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
  Future<void> updateOrderStatus(int pedidoId, String newStatus,
          {int? estimatedTime}) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() async => [];
}

class _FakeOrderRepo implements OrderRepository {
  List<OrderEntity> pending = [];

  @override
  Future<void> createOrder(OrderEntity order) async {}

  @override
  Future<List<OrderEntity>> getOrdersByUser(String userId) async => pending;

  @override
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId) async =>
      pending.where((o) => o.userId == userId).toList();

  @override
  Future<List<OrderEntity>> getLocalUnsentOrdersForUser(String userId) async =>
      pending.where((o) => o.userId == userId).toList();

  @override
  Future<int> countOrphanUnsyncedOrders() async => 0;

  @override
  Future<void> markAsSynced(String orderId) async {}

  @override
  Future<void> markOrdersAsSynced(List<String> orderIds) async {}

  @override
  Future<void> markSyncFailed(
    String orderId, {
    String? errorCode,
    String? errorMessage,
  }) async {}

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {}

  @override
  Future<void> deleteOrder(String orderId) async {}

  @override
  Future<void> deleteOrders(List<String> orderIds) async {}
}

Widget _buildApp({
  required _FakeMembresiaDs membresiaDs,
  required _FakeOrderRemote orderDs,
  required _FakeOrderRepo orderRepo,
  User? user,
}) {
  final userProvider = UserProvider(FakeUserRepository());
  if (user != null) userProvider.setUser(user);

  return MultiProvider(
    providers: [
      Provider<MembresiaRemoteDataSource>.value(value: membresiaDs),
      Provider<OrderRemoteDataSource>.value(value: orderDs),
      Provider<OrderRepository>.value(value: orderRepo),
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
    ],
    child: const MaterialApp(home: MemberOrdersListScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline con pending local muestra pedido y opciones', (tester) async {
    final orderRepo = _FakeOrderRepo()
      ..pending = [
        OrderEntity(
          id: 'local-uuid-1',
          userId: '1',
          clubId: 3,
          membresiaId: 10,
          status: 'pending',
          createdAt: DateTime(2026, 8, 30, 12),
          isSynced: false,
          items: [
            OrderItem(
              orderId: 'local-uuid-1',
              productId: '7',
              quantity: 1,
              productName: 'Batido de leche',
              options: const [
                OrderItemOption(
                  groupId: 3,
                  groupName: 'Sabores',
                  optionId: 6,
                  optionName: 'Frutilla',
                  quantity: 1,
                ),
                OrderItemOption(
                  groupId: 4,
                  groupName: 'Consistencia',
                  optionId: 9,
                  optionName: 'Líquido',
                  quantity: 1,
                ),
              ],
            ),
          ],
        ),
      ];
    final orderDs = _FakeOrderRemote()
      ..pageError = NetworkException('NetworkError de conexión');

    await tester.pumpWidget(_buildApp(
      membresiaDs: _FakeMembresiaDs(),
      orderDs: orderDs,
      orderRepo: orderRepo,
      user: User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pedido pendiente de envío'), findsOneWidget);
    expect(find.text('Pendiente de envío'), findsOneWidget);
    expect(find.textContaining('Batido de leche'), findsOneWidget);
    expect(find.textContaining('Sabores: Frutilla'), findsOneWidget);
    expect(find.textContaining('Consistencia: Líquido'), findsOneWidget);
    expect(find.textContaining('NetworkError'), findsNothing);
  });

  testWidgets('sin conexión y sin pedidos locales muestra empty amigable',
      (tester) async {
    final orderDs = _FakeOrderRemote()
      ..pageError = NetworkException('NetworkError de conexión');

    await tester.pumpWidget(_buildApp(
      membresiaDs: _FakeMembresiaDs(),
      orderDs: orderDs,
      orderRepo: _FakeOrderRepo(),
      user: User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'),
    ));
    await tester.pumpAndSettle();

    expect(find.text(OrderOfflineMessages.offlineEmptyTitle), findsOneWidget);
    expect(find.text(OrderOfflineMessages.offlineEmptyBody), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.textContaining('NetworkError'), findsNothing);
  });

  testWidgets('FAILED no muestra banner auto-envío pero sí mensaje seguro',
      (tester) async {
    final orderRepo = _FakeOrderRepo()
      ..pending = [
        OrderEntity(
          id: 'local-failed-1',
          userId: '1',
          clubId: 3,
          membresiaId: 10,
          status: 'pending',
          createdAt: DateTime(2026, 8, 30, 12),
          isSynced: false,
          syncStatus: OrderSyncStatus.failedPermanent,
          syncErrorCode: 'MEMBERSHIP_INACTIVE',
          items: [
            OrderItem(
              orderId: 'local-failed-1',
              productId: '7',
              quantity: 1,
              productName: 'Batido',
            ),
          ],
        ),
      ];

    await tester.pumpWidget(_buildApp(
      membresiaDs: _FakeMembresiaDs(),
      orderDs: _FakeOrderRemote(),
      orderRepo: orderRepo,
      user: User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo enviar'), findsOneWidget);
    expect(
      find.text(OrderOfflineMessages.failedOrderMessage('MEMBERSHIP_INACTIVE')),
      findsOneWidget,
    );
    expect(
      find.text(OrderOfflineMessages.localPendingBanner),
      findsNothing,
    );
    expect(find.text('Eliminar'), findsOneWidget);
  });

  testWidgets('fallo membresía por red sin locales muestra Sin conexión',
      (tester) async {
    final membresiaDs = _FakeMembresiaDs()
      ..getMembresiasError = NetworkException('NetworkError de conexión');

    await tester.pumpWidget(_buildApp(
      membresiaDs: membresiaDs,
      orderDs: _FakeOrderRemote(),
      orderRepo: _FakeOrderRepo(),
      user: User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'),
    ));
    await tester.pumpAndSettle();

    expect(find.text(OrderOfflineMessages.offlineEmptyTitle), findsOneWidget);
    expect(find.text(OrderOfflineMessages.offlineEmptyBody), findsOneWidget);
    expect(find.textContaining('NetworkError'), findsNothing);
    expect(find.textContaining('membresía'), findsNothing);
  });
}
