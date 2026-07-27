import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

class _Stub {
  _Stub(this.method, this.pathContains, this.statusCode, this.data);
  final String method;
  final String pathContains;
  final int statusCode;
  final dynamic data;
}

class _FakeAdapter implements HttpClientAdapter {
  final List<_Stub> _stubs = [];
  final List<RequestOptions> requests = [];

  void stub(
    String method,
    String pathContains, {
    int statusCode = 200,
    dynamic data,
  }) {
    _stubs.add(_Stub(method.toUpperCase(), pathContains, statusCode, data));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    for (final s in _stubs) {
      if (s.method == options.method && options.uri.path.contains(s.pathContains)) {
        final body = s.data is String ? s.data : jsonEncode(s.data);
        return ResponseBody.fromString(
          body,
          s.statusCode,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
    }
    return ResponseBody.fromString(
      '{"message":"not stubbed: ${options.method} ${options.uri.path}"}',
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _buildDio(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
  dio.httpClientAdapter = adapter;
  return dio;
}

dynamic async_(Future<void> Function() body) => body;

void main() {
  late _FakeAdapter adapter;
  late ClubRemoteDataSource ds;

  setUp(() {
    adapter = _FakeAdapter();
    ds = ClubRemoteDataSource(_buildDio(adapter));
  });

  group('getClubes', () {
    test('parsea lista directa', async_(() async {
      adapter.stub('GET', '/public/clubes', data: [
        {
          'id': 1,
          'hubId': 1,
          'anfitrionId': 2,
          'nombreClub': 'Club Norte',
          'direccion': 'Av. 1',
          'horario': '8-18',
          'lat': -17.7,
          'lng': -63.1,
          'estado': 'ACTIVO',
        },
      ]);

      final clubes = await ds.getClubes();
      expect(clubes, hasLength(1));
      expect(clubes.first.nombreClub, 'Club Norte');
      expect(clubes.first.lat, -17.7);
    }));

    test('parsea envoltorio content', async_(() async {
      adapter.stub('GET', '/public/clubes', data: {
        'content': [
          {'id': 2, 'hubId': 1, 'anfitrionId': 3, 'estado': 'APROBADO'},
        ],
      });
      final clubes = await ds.getClubes();
      expect(clubes, hasLength(1));
      expect(clubes.first.id, 2);
    }));

    test('parsea envoltorio data', async_(() async {
      adapter.stub('GET', '/public/clubes', data: {
        'data': [
          {'id': 3, 'hubId': 1, 'anfitrionId': 4},
        ],
      });
      final clubes = await ds.getClubes();
      expect(clubes, hasLength(1));
    }));

    test('lat/lng como String se parsean correctamente', async_(() async {
      adapter.stub('GET', '/public/clubes', data: [
        {
          'id': 4,
          'hubId': 1,
          'anfitrionId': 5,
          'lat': '-17.5',
          'lng': '-63.2',
        },
      ]);
      final clubes = await ds.getClubes();
      expect(clubes.first.lat, -17.5);
      expect(clubes.first.lng, -63.2);
    }));

    test('status != 200 lanza ServerException', async_(() async {
      adapter.stub('GET', '/public/clubes', statusCode: 500, data: {});
      await expectLater(() => ds.getClubes(), throwsA(isA<AppException>()));
    }));

    test('DioException se mapea a AppException', async_(() async {
      adapter.stub('GET', '/public/clubes', statusCode: 401, data: {});
      await expectLater(() => ds.getClubes(), throwsA(isA<AppException>()));
    }));
  });

  group('getClubesByHub', () {
    test('parsea lista', async_(() async {
      adapter.stub('GET', '/clubes', data: [
        {'id': 10, 'hubId': 1, 'anfitrionId': 1},
      ]);
      final clubes = await ds.getClubesByHub(1);
      expect(clubes, hasLength(1));
    }));

    test('parsea envoltorio data', async_(() async {
      adapter.stub('GET', '/clubes', data: {
        'data': [
          {'id': 11, 'hubId': 1, 'anfitrionId': 1},
        ],
      });
      final clubes = await ds.getClubesByHub(1);
      expect(clubes, hasLength(1));
    }));

    test('status != 200 lanza excepción', async_(() async {
      adapter.stub('GET', '/clubes', statusCode: 500, data: {});
      await expectLater(() => ds.getClubesByHub(1), throwsA(isA<AppException>()));
    }));
  });

  group('getMyClub', () {
    test('200 con Map devuelve Club', async_(() async {
      adapter.stub('GET', '/clubes/mio', data: {
        'id': 7,
        'hubId': 1,
        'anfitrionId': 2,
        'nombreClub': 'Mi Club',
      });
      final club = await ds.getMyClub();
      expect(club, isNotNull);
      expect(club!.id, 7);
    }));

    test('200 con List no vacía toma el primero', async_(() async {
      adapter.stub('GET', '/clubes/mio', data: [
        {'id': 8, 'hubId': 1, 'anfitrionId': 2},
      ]);
      final club = await ds.getMyClub();
      expect(club!.id, 8);
    }));

    test('200 con lista vacía devuelve null', async_(() async {
      adapter.stub('GET', '/clubes/mio', data: []);
      final club = await ds.getMyClub();
      expect(club, isNull);
    }));

    test('401 lanza UnauthorizedException', async_(() async {
      adapter.stub('GET', '/clubes/mio', statusCode: 401, data: {});
      await expectLater(
          () => ds.getMyClub(), throwsA(isA<UnauthorizedException>()));
    }));

    test('403 lanza ForbiddenException', async_(() async {
      adapter.stub('GET', '/clubes/mio', statusCode: 403, data: {});
      await expectLater(
          () => ds.getMyClub(), throwsA(isA<ForbiddenException>()));
    }));

    test('500 lanza ServerException', async_(() async {
      adapter.stub('GET', '/clubes/mio', statusCode: 500, data: {});
      await expectLater(() => ds.getMyClub(), throwsA(isA<ServerException>()));
    }));

    test('otro status lanza ServerException genérica', async_(() async {
      adapter.stub('GET', '/clubes/mio', statusCode: 418, data: {});
      await expectLater(() => ds.getMyClub(), throwsA(isA<AppException>()));
    }));
  });

  group('getClubById', () {
    test('200 devuelve Club', async_(() async {
      adapter.stub('GET', '/clubes/5', data: {
        'id': 5,
        'hubId': 1,
        'anfitrionId': 1,
        'nombreClub': 'Club X',
      });
      final club = await ds.getClubById(5);
      expect(club!.nombreClub, 'Club X');
    }));

    test('404 devuelve null sin lanzar', async_(() async {
      adapter.stub('GET', '/clubes/999', statusCode: 404, data: {});
      final club = await ds.getClubById(999);
      expect(club, isNull);
    }));

    test('500 lanza excepción mapeada', async_(() async {
      adapter.stub('GET', '/clubes/6', statusCode: 500, data: {});
      await expectLater(() => ds.getClubById(6), throwsA(isA<AppException>()));
    }));
  });

  group('getAnfitrion', () {
    test('éxito parsea Anfitrion', async_(() async {
      adapter.stub('GET', '/usuarios/1', data: {
        'id': 1,
        'nombre': 'Juan',
        'apellido': 'Perez',
        'email': 'juan@test.com',
        'telefono': '123',
        'redesSociales': '',
      });
      final a = await ds.getAnfitrion(1);
      expect(a.nombre, 'Juan');
    }));

    test('falla y devuelve Anfitrion vacío por defecto', async_(() async {
      // no stub -> 404 -> Exception('Failed to load anfitrion') -> catch -> default
      final a = await ds.getAnfitrion(99);
      expect(a.id, 99);
      expect(a.nombre, '');
    }));
  });

  group('getClubMembers', () {
    test('200 devuelve lista de miembros', async_(() async {
      adapter.stub('GET', '/membresias/club/3', data: [
        {
          'id': 1,
          'usuarioId': 1,
          'clubId': 3,
          'numeroSocio': 'S-1',
        },
      ]);
      final members = await ds.getClubMembers(3);
      expect(members, hasLength(1));
    }));

    test('status != 200 lanza excepción', async_(() async {
      adapter.stub('GET', '/membresias/club/4', statusCode: 500, data: {});
      await expectLater(
          () => ds.getClubMembers(4), throwsA(isA<AppException>()));
    }));
  });

  group('getClubMembersPage', () {
    test('parsea PagedResult', async_(() async {
      adapter.stub('GET', '/membresias/club/3/paginadas', data: {
        'content': [
          {'id': 1, 'usuarioId': 1, 'clubId': 3, 'numeroSocio': 'S-1'},
        ],
        'page': 0,
        'size': 20,
        'totalElements': 1,
        'totalPages': 1,
        'first': true,
        'last': true,
        'hasNext': false,
        'hasPrevious': false,
      });
      final page = await ds.getClubMembersPage(3, q: 'ana');
      expect(page.content, hasLength(1));

      final sentUri = adapter.requests.last.uri;
      expect(sentUri.queryParameters['q'], 'ana');
    }));

    test('respuesta no Map lanza ServerException', async_(() async {
      adapter.stub('GET', '/membresias/club/3/paginadas', data: [1, 2]);
      await expectLater(
          () => ds.getClubMembersPage(3), throwsA(isA<AppException>()));
    }));

    test('DioException se mapea', async_(() async {
      adapter.stub('GET', '/membresias/club/3/paginadas',
          statusCode: 500, data: {});
      await expectLater(
          () => ds.getClubMembersPage(3), throwsA(isA<AppException>()));
    }));
  });

  group('solicitarCreacionClub', () {
    test('lat NaN lanza excepción sin llamar a la red', async_(() async {
      await expectLater(
        () => ds.solicitarCreacionClub(
          anfitrionId: 1,
          nombreClub: 'X',
          direccion: 'Y',
          horario: '8-18',
          lat: double.nan,
          lng: -63.0,
        ),
        throwsException,
      );
      expect(adapter.requests, isEmpty);
    }));

    test('éxito hace POST', async_(() async {
      adapter.stub('POST', '/clubes', statusCode: 201, data: {});
      await ds.solicitarCreacionClub(
        anfitrionId: 1,
        nombreClub: 'X',
        direccion: 'Y',
        horario: '8-18',
        lat: -17.0,
        lng: -63.0,
      );
      expect(adapter.requests, hasLength(1));
    }));

    test('error del servidor lanza excepción', async_(() async {
      adapter.stub('POST', '/clubes', statusCode: 500, data: {});
      await expectLater(
        () => ds.solicitarCreacionClub(
          anfitrionId: 1,
          nombreClub: 'X',
          direccion: 'Y',
          horario: '8-18',
          lat: -17.0,
          lng: -63.0,
        ),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('updateClub', () {
    test('éxito no lanza y remueve fotoUrl del body', async_(() async {
      adapter.stub('PUT', '/clubes/5', statusCode: 200, data: {});
      await ds.updateClub(5, {'nombreClub': 'Nuevo', 'fotoUrl': 'x'});
      expect(adapter.requests, hasLength(1));
    }));

    test('error lanza AppException', async_(() async {
      adapter.stub('PUT', '/clubes/5', statusCode: 500, data: {});
      await expectLater(
          () => ds.updateClub(5, {}), throwsA(isA<AppException>()));
    }));
  });

  group('getFotosClub', () {
    test('200 parsea lista de fotos', async_(() async {
      adapter.stub('GET', '/fotos-club/club/3', data: [
        {'id': 1, 'clubId': 3, 'urlFoto': 'url1', 'tipo': 'PORTADA'},
      ]);
      final fotos = await ds.getFotosClub(3);
      expect(fotos, hasLength(1));
    }));

    test('error devuelve lista vacía', async_(() async {
      adapter.stub('GET', '/fotos-club/club/9', statusCode: 500, data: {});
      final fotos = await ds.getFotosClub(9);
      expect(fotos, isEmpty);
    }));
  });

  group('subirFotoClub', () {
    test('éxito no lanza', async_(() async {
      adapter.stub('POST', '/fotos-club/subir', statusCode: 201, data: {});
      await ds.subirFotoClub(3, 'http://x.png');
      expect(adapter.requests, hasLength(1));
    }));

    test('error lanza excepción', async_(() async {
      adapter.stub('POST', '/fotos-club/subir', statusCode: 500, data: {});
      await expectLater(
        () => ds.subirFotoClub(3, 'http://x.png'),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('eliminarFoto', () {
    test('hace DELETE', async_(() async {
      adapter.stub('DELETE', '/fotos-club/9', statusCode: 200, data: {});
      await ds.eliminarFoto(9);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'DELETE');
    }));
  });

  group('getReferidosPorMembresia', () {
    test('200 parsea lista', async_(() async {
      adapter.stub('GET', '/membresias/4/referidos', data: [
        {'id': 1, 'usuarioId': 1, 'clubId': 3, 'numeroSocio': 'S-1'},
      ]);
      final referidos = await ds.getReferidosPorMembresia(4);
      expect(referidos, hasLength(1));
    }));

    test('404 devuelve lista vacía', async_(() async {
      adapter.stub('GET', '/membresias/5/referidos', statusCode: 404, data: {});
      final referidos = await ds.getReferidosPorMembresia(5);
      expect(referidos, isEmpty);
    }));

    test('500 lanza excepción', async_(() async {
      adapter.stub('GET', '/membresias/6/referidos', statusCode: 500, data: {});
      await expectLater(
        () => ds.getReferidosPorMembresia(6),
        throwsA(isA<AppException>()),
      );
    }));
  });
}
