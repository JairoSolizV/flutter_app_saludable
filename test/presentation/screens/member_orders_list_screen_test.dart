import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/data/datasources/remote/membresia_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/attendance.dart';
import 'package:flutter_app_saludable/domain/entities/arbol_referidos.dart';
import 'package:flutter_app_saludable/domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/member/member_orders_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_user_repository.dart';

class _FakeMembresiaRemoteDataSource implements MembresiaRemoteDataSource {
  List<ClubMembership> membresias = [];
  Object? error;
  int calls = 0;

  @override
  Future<List<ClubMembership>> getMembresiasPorUsuario(int usuarioId) async {
    calls++;
    if (error != null) throw error!;
    return membresias;
  }

  @override
  Future<void> activarSocio({
    required int clubId,
    required String activationPayload,
    int? referidoPorMembresiaId,
    String? comoConocio,
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

class _FakeOrderRemoteDataSource implements OrderRemoteDataSource {
  PagedResult<Map<String, dynamic>>? pageToReturn;
  Object? pageError;
  int socioPageCalls = 0;

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(
    int membresiaId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) async {
    socioPageCalls++;
    if (pageError != null) throw pageError!;
    return pageToReturn ??
        PagedResult<Map<String, dynamic>>.empty(page: page, size: size);
  }

  @override
  Future<void> sendOrder(OrderEntity order, List<OrderItem> items) =>
      throw UnimplementedError();

  @override
  Future<void> createCounterSale({
    required int clubId,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId) =>
      throw UnimplementedError();

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(
    int clubId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus,
          {int? estimatedTime}) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() =>
      throw UnimplementedError();
}

ClubMembership _membresia(int id, {int clubId = 5}) {
  return ClubMembership(
    id: id,
    usuarioId: 1,
    usuarioNombre: 'Ana',
    clubId: clubId,
    clubNombre: 'Club Norte',
    nivelId: 1,
    nivelNombre: 'Bronce',
    numeroSocio: 'S-0001',
    puntosAcumulados: 5,
    fechaRegistro: '2024-01-01',
    estado: 'ACTIVO',
  );
}

Widget _buildApp({
  required _FakeMembresiaRemoteDataSource membresiaDs,
  required _FakeOrderRemoteDataSource orderDs,
  User? user,
}) {
  final userProvider = UserProvider(FakeUserRepository());
  if (user != null) userProvider.setUser(user);

  return MultiProvider(
    providers: [
      Provider<MembresiaRemoteDataSource>.value(value: membresiaDs),
      Provider<OrderRemoteDataSource>.value(value: orderDs),
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
    ],
    child: const MaterialApp(
      home: MemberOrdersListScreen(),
    ),
  );
}

void main() {
  group('MemberOrdersListScreen', () {
    testWidgets('sin usuario autenticado muestra error', (tester) async {
      final membresiaDs = _FakeMembresiaRemoteDataSource();
      final orderDs = _FakeOrderRemoteDataSource();

      await tester.pumpWidget(
          _buildApp(membresiaDs: membresiaDs, orderDs: orderDs, user: null));
      await tester.pumpAndSettle();

      expect(find.textContaining('Usuario no autenticado'), findsOneWidget);
      expect(membresiaDs.calls, 0);
    });

    testWidgets('sin membresías muestra listas vacías sin error',
        (tester) async {
      final membresiaDs = _FakeMembresiaRemoteDataSource();
      final orderDs = _FakeOrderRemoteDataSource();

      await tester.pumpWidget(_buildApp(
        membresiaDs: membresiaDs,
        orderDs: orderDs,
        user: User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No hay pedidos en esta sección'), findsOneWidget);
    });

    testWidgets('error al buscar membresía muestra mensaje de error',
        (tester) async {
      final membresiaDs = _FakeMembresiaRemoteDataSource()
        ..error = Exception('Fallo de red');
      final orderDs = _FakeOrderRemoteDataSource();

      await tester.pumpWidget(_buildApp(
        membresiaDs: membresiaDs,
        orderDs: orderDs,
        user: User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('con pedidos activos los muestra con badge de estado',
        (tester) async {
      final membresiaDs = _FakeMembresiaRemoteDataSource()
        ..membresias = [_membresia(9)];
      final orderDs = _FakeOrderRemoteDataSource()
        ..pageToReturn = PagedResult<Map<String, dynamic>>(
          content: [
            {
              'id': 1,
              'estado': 'PREPARANDO',
              'clubNombre': 'Club Norte',
              'tiempoEstimadoMinutos': 10,
              'fechaPedido': '2024-01-01T10:00:00',
              'items': [
                {'productoNombre': 'Batido', 'cantidad': 2},
              ],
            },
          ],
          page: 0,
          size: 20,
          totalElements: 1,
          totalPages: 1,
          first: true,
          last: true,
          hasNext: false,
          hasPrevious: false,
        );

      await tester.pumpWidget(_buildApp(
        membresiaDs: membresiaDs,
        orderDs: orderDs,
        user: User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pedido #1'), findsOneWidget);
      expect(find.text('Preparando'), findsOneWidget);
      expect(find.textContaining('2 x Batido'), findsOneWidget);
      expect(orderDs.socioPageCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('FAB sin membresía activa muestra snackbar', (tester) async {
      final membresiaDs = _FakeMembresiaRemoteDataSource();
      final orderDs = _FakeOrderRemoteDataSource();

      await tester.pumpWidget(_buildApp(
        membresiaDs: membresiaDs,
        orderDs: orderDs,
        user: User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo Pedido'));
      await tester.pump();

      expect(find.text('No tienes un club asociado'), findsOneWidget);
    });

    testWidgets('cambiar a la pestaña Historial filtra pedidos entregados',
        (tester) async {
      final membresiaDs = _FakeMembresiaRemoteDataSource()
        ..membresias = [_membresia(9)];
      final orderDs = _FakeOrderRemoteDataSource()
        ..pageToReturn = PagedResult<Map<String, dynamic>>(
          content: [
            {'id': 1, 'estado': 'ENTREGADO', 'clubNombre': 'Club Norte'},
            {'id': 2, 'estado': 'RECIBIDO', 'clubNombre': 'Club Norte'},
          ],
          page: 0,
          size: 20,
          totalElements: 2,
          totalPages: 1,
          first: true,
          last: true,
          hasNext: false,
          hasPrevious: false,
        );

      await tester.pumpWidget(_buildApp(
        membresiaDs: membresiaDs,
        orderDs: orderDs,
        user: User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pedido #2'), findsOneWidget);

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pedido #1'), findsOneWidget);
    });
  });
}
