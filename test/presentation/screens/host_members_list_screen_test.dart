import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/pre_socio_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/domain/entities/mision_pre_socio.dart';
import 'package:flutter_app_saludable/domain/entities/pre_socio.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/host/members/host_members_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_user_repository.dart';

class _FakeClubRemoteDataSource extends ClubRemoteDataSource {
  _FakeClubRemoteDataSource() : super(Dio());

  Club? clubToReturn;
  Object? getMyClubError;
  PagedResult<ClubMembership>? pageToReturn;
  Object? pageError;
  int membersPageCalls = 0;

  @override
  Future<Club?> getMyClub() async {
    if (getMyClubError != null) throw getMyClubError!;
    return clubToReturn;
  }

  @override
  Future<PagedResult<ClubMembership>> getClubMembersPage(
    int clubId, {
    int page = 0,
    int size = 20,
    String? q,
  }) async {
    membersPageCalls++;
    if (pageError != null) throw pageError!;
    return pageToReturn ?? PagedResult<ClubMembership>.empty(page: page, size: size);
  }
}

class _FakePreSocioRemoteDataSource implements PreSocioRemoteDataSource {
  List<PreSocio> preSocios = [];
  Object? error;

  @override
  Future<List<PreSocio>> getPreSocios(int clubId) async {
    if (error != null) throw error!;
    return preSocios;
  }

  @override
  Future<PreSocio> crearPreSocio({
    required int clubId,
    required String nombre,
    required String telefono,
    int? referidoPorMembresiaId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> actualizarPreSocio(int preSocioId, String estado) =>
      throw UnimplementedError();

  @override
  Future<MisionPreSocio> crearMision({
    required int preSocioId,
    required String nombre,
    String? descripcion,
    required int metaCantidad,
    String? fechaLimite,
  }) =>
      throw UnimplementedError();

  @override
  Future<MisionPreSocio> incrementarProgreso(int misionId) =>
      throw UnimplementedError();

  @override
  Future<void> eliminarMision(int misionId) => throw UnimplementedError();
}

ClubMembership _member(int id, String nombre) {
  return ClubMembership(
    id: id,
    usuarioId: id,
    usuarioNombre: nombre,
    clubId: 1,
    clubNombre: 'Club 1',
    nivelId: 1,
    nivelNombre: 'Bronce',
    numeroSocio: 'S-000$id',
    puntosAcumulados: 10,
    fechaRegistro: '2024-01-01',
    estado: 'ACTIVO',
  );
}

Widget _buildApp({
  required _FakeClubRemoteDataSource clubDs,
  required _FakePreSocioRemoteDataSource preSocioDs,
}) {
  final userProvider = UserProvider(FakeUserRepository())
    ..setUser(User(id: '1', name: 'Ana', email: 'ana@test.com', role: 'host'));

  return MultiProvider(
    providers: [
      Provider<ClubRemoteDataSource>.value(value: clubDs),
      Provider<PreSocioRemoteDataSource>.value(value: preSocioDs),
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
    ],
    child: const MaterialApp(
      home: HostMembersListScreen(),
    ),
  );
}

void main() {
  group('HostMembersListScreen', () {
    testWidgets('sin club asociado muestra error y permite reintentar',
        (tester) async {
      final clubDs = _FakeClubRemoteDataSource()
        ..getMyClubError = Exception('No se encontró un club asociado a este anfitrión.');
      final preSocioDs = _FakePreSocioRemoteDataSource();

      await tester.pumpWidget(_buildApp(clubDs: clubDs, preSocioDs: preSocioDs));
      await tester.pumpAndSettle();

      expect(
        find.text('No se encontró un club asociado a este anfitrión.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se encontró un club asociado a este anfitrión.'),
        findsOneWidget,
      );
    });

    testWidgets('con club pero sin socios muestra estado vacío',
        (tester) async {
      final clubDs = _FakeClubRemoteDataSource()
        ..clubToReturn = Club(
          id: 1,
          hubId: 1,
          hubNombre: 'Hub',
          anfitrionId: 1,
          anfitrionNombre: 'Ana',
          nombreClub: 'Club 1',
          direccion: 'Dir',
          horario: '8-18',
          lat: 0,
          lng: 0,
          estado: 'ACTIVO',
        )
        ..pageToReturn = PagedResult<ClubMembership>.empty();
      final preSocioDs = _FakePreSocioRemoteDataSource();

      await tester.pumpWidget(_buildApp(clubDs: clubDs, preSocioDs: preSocioDs));
      await tester.pumpAndSettle();

      expect(find.text('No hay socios registrados aún.'), findsOneWidget);
      expect(clubDs.membersPageCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('con socios los muestra en la lista con conteo total',
        (tester) async {
      final clubDs = _FakeClubRemoteDataSource()
        ..clubToReturn = Club(
          id: 1,
          hubId: 1,
          hubNombre: 'Hub',
          anfitrionId: 1,
          anfitrionNombre: 'Ana',
          nombreClub: 'Club 1',
          direccion: 'Dir',
          horario: '8-18',
          lat: 0,
          lng: 0,
          estado: 'ACTIVO',
        )
        ..pageToReturn = PagedResult<ClubMembership>(
          content: [_member(1, 'Carla'), _member(2, 'Diego')],
          page: 0,
          size: 20,
          totalElements: 2,
          totalPages: 1,
          first: true,
          last: true,
          hasNext: false,
          hasPrevious: false,
        );
      final preSocioDs = _FakePreSocioRemoteDataSource();

      await tester.pumpWidget(_buildApp(clubDs: clubDs, preSocioDs: preSocioDs));
      await tester.pumpAndSettle();

      expect(find.text('Total de Socios: 2'), findsOneWidget);
      expect(find.text('Carla'), findsOneWidget);
      expect(find.text('Diego'), findsOneWidget);
    });

    testWidgets('búsqueda dispara nueva carga tras el debounce',
        (tester) async {
      final clubDs = _FakeClubRemoteDataSource()
        ..clubToReturn = Club(
          id: 1,
          hubId: 1,
          hubNombre: 'Hub',
          anfitrionId: 1,
          anfitrionNombre: 'Ana',
          nombreClub: 'Club 1',
          direccion: 'Dir',
          horario: '8-18',
          lat: 0,
          lng: 0,
          estado: 'ACTIVO',
        )
        ..pageToReturn = PagedResult<ClubMembership>(
          content: [_member(1, 'Carla')],
          page: 0,
          size: 20,
          totalElements: 1,
          totalPages: 1,
          first: true,
          last: true,
          hasNext: false,
          hasPrevious: false,
        );
      final preSocioDs = _FakePreSocioRemoteDataSource();

      await tester.pumpWidget(_buildApp(clubDs: clubDs, preSocioDs: preSocioDs));
      await tester.pumpAndSettle();

      final callsBefore = clubDs.membersPageCalls;
      await tester.enterText(find.byType(TextField).first, 'car');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(clubDs.membersPageCalls, greaterThan(callsBefore));
    });
  });
}
