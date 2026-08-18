import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/membresia_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/arbol_referidos.dart';
import 'package:flutter_app_saludable/domain/entities/attendance.dart';
import 'package:flutter_app_saludable/domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/presentation/screens/host/members/host_member_registration_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class _FakeClubRemoteDataSource extends ClubRemoteDataSource {
  _FakeClubRemoteDataSource() : super(Dio());

  @override
  Future<List<ClubMembership>> getClubMembers(int clubId) async => [];
}

class _FakeMembresiaRemoteDataSource implements MembresiaRemoteDataSource {
  int activarCalls = 0;
  bool? lastEsClientePreferenteODistribuidor;

  @override
  Future<void> activarSocio({
    required int clubId,
    required String activationPayload,
    int? referidoPorMembresiaId,
    String? comoConocio,
    required bool esClientePreferenteODistribuidor,
  }) async {
    activarCalls++;
    lastEsClientePreferenteODistribuidor = esClientePreferenteODistribuidor;
  }

  @override
  Future<void> crearMembresia({
    required int usuarioId,
    required int clubId,
    int? nivelId,
    Map<String, dynamic>? extraData,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<ClubMembership>> getMembresiasPorUsuario(int usuarioId) =>
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
  }) async =>
      PagedResult<ClubMembership>.empty(page: page, size: size);

  @override
  Future<ArbolReferidos> getArbolReferidos(int membresiaId) =>
      throw UnimplementedError();
}

Widget _buildApp(_FakeMembresiaRemoteDataSource membresiaDs) {
  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('Home')),
        routes: [
          GoRoute(
            path: 'register',
            builder: (_, __) => const HostMemberRegistrationScreen(
              qrPayload: 'ACTIVATE:123',
              clubId: 1,
            ),
          ),
        ],
      ),
    ],
  );

  return MultiProvider(
    providers: [
      Provider<ClubRemoteDataSource>.value(value: _FakeClubRemoteDataSource()),
      Provider<MembresiaRemoteDataSource>.value(value: membresiaDs),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeMembresiaRemoteDataSource membresiaDs,
) async {
  await tester.pumpWidget(_buildApp(membresiaDs));
  await tester.pump();
  await tester.pump();
}

void main() {
  const preguntaLegal =
      '¿Usted, su cónyuge o pareja de vida actualmente es cliente preferente o distribuidor independiente de Herbalife?';
  const mensajeBloqueo =
      'Un cliente preferente o distribuidor independiente de Herbalife no puede registrarse como socio.';

  group('HostMemberRegistrationScreen', () {
    testWidgets('muestra la pregunta legal sin opción preseleccionada',
        (tester) async {
      await _pumpScreen(tester, _FakeMembresiaRemoteDataSource());

      expect(find.text(preguntaLegal), findsOneWidget);
      expect(find.text('SÍ'), findsOneWidget);
      expect(find.text('NO'), findsOneWidget);

      final segmented =
          tester.widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>));
      expect(segmented.selected, isEmpty);
    });

    testWidgets('confirmar sin responder no llama al data source',
        (tester) async {
      final membresiaDs = _FakeMembresiaRemoteDataSource();
      await _pumpScreen(tester, membresiaDs);

      await tester.ensureVisible(find.text('CONFIRMAR ACTIVACIÓN'));
      await tester.tap(find.text('CONFIRMAR ACTIVACIÓN'));
      await tester.pump();

      expect(
        find.text('Debe responder esta declaración para continuar'),
        findsOneWidget,
      );
      expect(membresiaDs.activarCalls, 0);
    });

    testWidgets('seleccionar SÍ bloquea la activación y no llama al endpoint',
        (tester) async {
      final membresiaDs = _FakeMembresiaRemoteDataSource();
      await _pumpScreen(tester, membresiaDs);

      await tester.tap(find.text('SÍ'));
      await tester.pump();
      await tester.ensureVisible(find.text('CONFIRMAR ACTIVACIÓN'));
      await tester.tap(find.text('CONFIRMAR ACTIVACIÓN'));
      await tester.pump();

      expect(find.text(mensajeBloqueo), findsOneWidget);
      expect(membresiaDs.activarCalls, 0);

      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(find.text('CONFIRMAR ACTIVACIÓN'), findsOneWidget);
      expect(find.text(preguntaLegal), findsOneWidget);
    });

    testWidgets('seleccionar NO ejecuta la activación con false',
        (tester) async {
      final membresiaDs = _FakeMembresiaRemoteDataSource();
      await _pumpScreen(tester, membresiaDs);

      await tester.tap(find.text('NO'));
      await tester.pump();
      await tester.ensureVisible(find.text('CONFIRMAR ACTIVACIÓN'));
      await tester.tap(find.text('CONFIRMAR ACTIVACIÓN'));
      await tester.pump();
      await tester.pump();

      expect(membresiaDs.activarCalls, 1);
      expect(membresiaDs.lastEsClientePreferenteODistribuidor, isFalse);
    });
  });
}
