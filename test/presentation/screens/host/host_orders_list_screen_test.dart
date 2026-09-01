import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/host/host_orders_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/fake_user_repository.dart';

class _FakeClubDs extends ClubRemoteDataSource {
  _FakeClubDs() : super(Dio());

  @override
  Future<Club?> getMyClub() async => Club(
        id: 1,
        hubId: 1,
        hubNombre: 'Hub',
        anfitrionId: 10,
        anfitrionNombre: 'Host',
        nombreClub: 'Club Test',
        direccion: '',
        horario: '',
        lat: 0,
        lng: 0,
        estado: 'ACTIVO',
      );
}

class _TrackingOrderDs implements OrderRemoteDataSource {
  String? lastEstadoFilter;
  String? lastStatusUpdate;
  int? lastUpdatedPedidoId;
  int cancelCalls = 0;
  int fetchCalls = 0;

  final List<Map<String, dynamic>> orders;

  _TrackingOrderDs(this.orders);

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(
    int clubId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) async {
    fetchCalls++;
    lastEstadoFilter = estado;
    final filtered = estado == null
        ? orders
        : orders
            .where((o) => (o['estado'] as String?)?.toUpperCase() == estado)
            .toList();
    return PagedResult(
      content: filtered,
      page: page,
      size: size,
      totalElements: filtered.length,
      totalPages: 1,
      first: page == 0,
      last: true,
      hasNext: false,
      hasPrevious: page > 0,
    );
  }

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus,
      {int? estimatedTime}) async {
    lastUpdatedPedidoId = pedidoId;
    lastStatusUpdate = newStatus;
    if (newStatus == 'CANCELADO') cancelCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildApp(OrderRemoteDataSource orderDs) {
  final userProvider = UserProvider(FakeUserRepository())
    ..setUser(User(
      id: '10',
      name: 'Host Test',
      email: 'host@test.com',
      role: 'host',
    ));

  return MultiProvider(
    providers: [
      Provider<OrderRemoteDataSource>.value(value: orderDs),
      Provider<ClubRemoteDataSource>.value(value: _FakeClubDs()),
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
    ],
    child: const MaterialApp(home: HostOrdersListScreen()),
  );
}

Map<String, dynamic> _order({
  required int id,
  required String estado,
  String? socioNombre,
  String? socioTelefono,
  String? numeroSocio,
}) {
  return {
    'id': id,
    'estado': estado,
    'fechaPedido': DateTime(2026, 1, 15, 10, 30).toUtc().toIso8601String(),
    'membresiaNumeroSocio': numeroSocio,
    'socioNombre': socioNombre,
    'socioTelefono': socioTelefono,
    'tipoConsumo': 'EN_LUGAR',
    'items': [
      {
        'productoNombre': 'Batido',
        'cantidad': 1,
        'opciones': <dynamic>[],
      }
    ],
  };
}

void main() {
  testWidgets('card muestra nombre, codigo y telefono del socio', (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(
        id: 42,
        estado: 'RECIBIDO',
        socioNombre: 'Ruth Toro',
        socioTelefono: '+59173429001',
        numeroSocio: 'CL-000003',
      ),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    expect(find.text('Ruth Toro'), findsOneWidget);
    expect(find.text('CL-000003'), findsOneWidget);
    expect(find.text('+59173429001'), findsOneWidget);
  });

  testWidgets('telefono null no muestra fila de telefono', (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(
        id: 43,
        estado: 'RECIBIDO',
        socioNombre: 'Ruth Toro',
        numeroSocio: 'CL-000003',
      ),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.phone), findsNothing);
  });

  testWidgets('CANCELADO muestra badge Cancelado', (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(
        id: 44,
        estado: 'CANCELADO',
        socioNombre: 'Ruth Toro',
        numeroSocio: 'CL-000003',
      ),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.text('Pendiente'), findsNothing);
  });

  testWidgets('pending muestra cancelar y completed no', (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(id: 45, estado: 'RECIBIDO', socioNombre: 'A', numeroSocio: 'CL-1'),
      _order(id: 46, estado: 'ENTREGADO', socioNombre: 'B', numeroSocio: 'CL-2'),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar pedido'), findsOneWidget);
    expect(find.text('Preparar'), findsOneWidget);
  });

  testWidgets('pending muestra cancelar y preparar en la misma fila',
      (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(id: 53, estado: 'RECIBIDO', socioNombre: 'Ruth', numeroSocio: 'CL-9'),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    final sharedRow = find.ancestor(
      of: find.text('Preparar'),
      matching: find.ancestor(
        of: find.text('Cancelar pedido'),
        matching: find.byType(Row),
      ),
    );
    expect(sharedRow, findsOneWidget);
    expect(
      find.descendant(of: sharedRow, matching: find.text('Cancelar pedido')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sharedRow, matching: find.text('Preparar')),
      findsOneWidget,
    );
  });

  testWidgets('pending cancelar abre dialogo de confirmacion', (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(id: 54, estado: 'RECIBIDO', socioNombre: 'Ruth', numeroSocio: 'CL-10'),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar pedido'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '¿Deseas cancelar este pedido? Dejará de contabilizarse como venta.',
      ),
      findsOneWidget,
    );
    expect(find.text('Volver'), findsOneWidget);
  });

  testWidgets('pending preparar abre dialogo de tiempo estimado',
      (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(id: 55, estado: 'RECIBIDO', socioNombre: 'Ruth', numeroSocio: 'CL-11'),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preparar'));
    await tester.pumpAndSettle();

    expect(find.text('Tiempo Estimado'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
  });

  testWidgets('cancelled no muestra acciones de flujo', (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(
        id: 47,
        estado: 'CANCELADO',
        socioNombre: 'Ruth',
        numeroSocio: 'CL-3',
      ),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    expect(find.text('Preparar'), findsNothing);
    expect(find.text('Cancelar pedido'), findsNothing);
  });

  testWidgets('confirmar cancelacion llama CANCELADO', (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(id: 48, estado: 'LISTO', socioNombre: 'Ruth', numeroSocio: 'CL-4'),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar pedido').last);
    await tester.pumpAndSettle();

    expect(orderDs.cancelCalls, 1);
    expect(orderDs.lastStatusUpdate, 'CANCELADO');
    expect(orderDs.lastUpdatedPedidoId, 48);
  });

  testWidgets('filtro Cancelados envia estado CANCELADO', (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(id: 49, estado: 'CANCELADO', socioNombre: 'Ruth', numeroSocio: 'CL-5'),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelados'));
    await tester.pumpAndSettle();

    expect(orderDs.lastEstadoFilter, 'CANCELADO');
  });

  testWidgets('preparing muestra boton Cancelar pedido', (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(id: 50, estado: 'PREPARANDO', socioNombre: 'Ruth', numeroSocio: 'CL-6'),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar pedido'), findsOneWidget);
  });

  testWidgets('ready muestra boton Cancelar pedido', (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(id: 51, estado: 'LISTO', socioNombre: 'Ruth', numeroSocio: 'CL-7'),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar pedido'), findsOneWidget);
  });

  testWidgets('volver en dialogo no cancela ni refresca', (tester) async {
    final orderDs = _TrackingOrderDs([
      _order(id: 52, estado: 'RECIBIDO', socioNombre: 'Ruth', numeroSocio: 'CL-8'),
    ]);

    await tester.pumpWidget(_buildApp(orderDs));
    await tester.pumpAndSettle();

    final fetchesTrasCarga = orderDs.fetchCalls;

    await tester.tap(find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(orderDs.cancelCalls, 0);
    expect(orderDs.lastStatusUpdate, isNull);
    expect(orderDs.lastUpdatedPedidoId, isNull);
    expect(orderDs.fetchCalls, fetchesTrasCarga);
  });
}
