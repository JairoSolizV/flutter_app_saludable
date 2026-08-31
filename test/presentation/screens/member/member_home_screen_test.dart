import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/data/datasources/remote/membresia_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/attendance.dart';
import 'package:flutter_app_saludable/domain/entities/arbol_referidos.dart';
import 'package:flutter_app_saludable/domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/member/member_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/fake_user_repository.dart';

ClubMembership _membership({
  String numeroSocio = 'CV-00000123',
  int puntos = 120,
  String clubNombre = 'Club prueba',
}) {
  return ClubMembership(
    id: 1,
    usuarioId: 10,
    usuarioNombre: 'Ana Test',
    clubId: 3,
    clubNombre: clubNombre,
    nivelId: 1,
    nivelNombre: 'Socio',
    numeroSocio: numeroSocio,
    puntosAcumulados: puntos,
    fechaRegistro: '2026-01-01',
    estado: 'ACTIVO',
  );
}

Attendance _attendance(int id) => Attendance(
      id: id,
      membresiaId: 1,
      membresiaNumeroSocio: 'CV-00000123',
      clubId: 3,
      clubNombre: 'Club prueba',
      fechaHora: '2026-08-31T10:00:00',
      fechaDia: '2026-08-31',
      estado: 'REGISTRADA',
    );

class _FakeMembresiaDs implements MembresiaRemoteDataSource {
  List<ClubMembership> membresias = [];
  List<Attendance> asistencias = [];
  Object? membershipError;
  Object? attendanceError;
  int loadCalls = 0;

  @override
  Future<List<ClubMembership>> getMembresiasPorUsuario(int usuarioId) async {
    loadCalls++;
    if (membershipError != null) throw membershipError!;
    return membresias;
  }

  @override
  Future<List<Attendance>> getAsistencias(int membresiaId) async {
    if (attendanceError != null) throw attendanceError!;
    return asistencias;
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
  Future<AsistenciaResponse> registrarAsistencia({
    required int membresiaId,
    required int clubId,
    required double latitud,
    required double longitud,
    double? precisionMetros,
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

Widget _homeApp(_FakeMembresiaDs membresiaDs) {
  final userProvider = UserProvider(FakeUserRepository())
    ..setUser(User(
      id: '10',
      name: 'Ana Test',
      email: 'ana@test.com',
      role: 'SOCIO',
    ));

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      Provider<MembresiaRemoteDataSource>.value(value: membresiaDs),
    ],
    child: const MaterialApp(home: MemberHomeScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home no muestra tarjeta de fidelidad ni sellos', (tester) async {
    final ds = _FakeMembresiaDs()
      ..membresias = [_membership()]
      ..asistencias = List.generate(8, (i) => _attendance(i + 1));

    await tester.pumpWidget(_homeApp(ds));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Mi membresía'), findsOneWidget);
    expect(find.text('Tarjeta de Fidelidad'), findsNothing);
    expect(find.textContaining('Sellos'), findsNothing);
    expect(find.textContaining('Recompensa'), findsNothing);
    expect(find.textContaining('meta'), findsNothing);
    expect(find.text('Club prueba'), findsOneWidget);
    expect(find.text('120 pts'), findsOneWidget);
    expect(find.text('CV-00000123'), findsOneWidget);
    expect(find.text('8 asistencias'), findsOneWidget);
  });

  testWidgets('12 asistencias muestra 12 en home', (tester) async {
    final ds = _FakeMembresiaDs()
      ..membresias = [_membership()]
      ..asistencias = List.generate(12, (i) => _attendance(i + 1));

    await tester.pumpWidget(_homeApp(ds));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('12 asistencias'), findsOneWidget);
  });

  testWidgets('sin membresía muestra nuevo empty state', (tester) async {
    await tester.pumpWidget(_homeApp(_FakeMembresiaDs()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Únete a un club para ver la información de tu membresía.'),
      findsOneWidget,
    );
    expect(find.textContaining('fidelidad'), findsNothing);
  });

  testWidgets('mantiene acciones Registrar Asistencia y Hacer Pedido',
      (tester) async {
    final ds = _FakeMembresiaDs()
      ..membresias = [_membership()]
      ..asistencias = [];

    await tester.pumpWidget(_homeApp(ds));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Registrar Asistencia'), findsOneWidget);
    expect(find.text('Hacer Pedido'), findsOneWidget);
  });

  testWidgets('membresía visible aunque asistencias fallen', (tester) async {
    final ds = _FakeMembresiaDs()
      ..membresias = [_membership()]
      ..attendanceError = Exception('network');

    await tester.pumpWidget(_homeApp(ds));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Mi membresía'), findsOneWidget);
    expect(find.text('Club prueba'), findsOneWidget);
    expect(find.text('120 pts'), findsOneWidget);
    expect(find.text('No disponible'), findsOneWidget);
  });

  testWidgets('refresh recarga datos', (tester) async {
    final ds = _FakeMembresiaDs()
      ..membresias = [_membership(puntos: 50)]
      ..asistencias = [_attendance(1)];

    await tester.pumpWidget(_homeApp(ds));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ds.loadCalls, 1);

    ds.membresias = [_membership(puntos: 200)];
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(ds.loadCalls, greaterThan(1));
  });
}
