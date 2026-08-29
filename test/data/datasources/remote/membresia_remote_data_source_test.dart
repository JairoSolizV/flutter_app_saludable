import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/membresia_remote_data_source.dart';
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
  late MembresiaRemoteDataSourceImpl ds;

  setUp(() {
    adapter = _FakeAdapter();
    ds = MembresiaRemoteDataSourceImpl(_buildDio(adapter));
  });

  group('crearMembresia', () {
    test('éxito hace POST con nivelId cuando es positivo', async_(() async {
      adapter.stub('POST', '/membresias', statusCode: 201, data: {});
      await ds.crearMembresia(usuarioId: 1, clubId: 2, nivelId: 3);

      final sentUri = adapter.requests.single.uri;
      expect(sentUri.queryParameters['nivelId'], '3');
    }));

    test('nivelId <= 0 no se incluye en query', async_(() async {
      adapter.stub('POST', '/membresias', statusCode: 200, data: {});
      await ds.crearMembresia(usuarioId: 1, clubId: 2, nivelId: 0);

      final sentUri = adapter.requests.single.uri;
      expect(sentUri.queryParameters.containsKey('nivelId'), isFalse);
    }));

    test('error del servidor se mapea', async_(() async {
      adapter.stub('POST', '/membresias', statusCode: 500, data: {});
      await expectLater(
        () => ds.crearMembresia(usuarioId: 1, clubId: 2),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('activarSocio', () {
    test('éxito hace POST con boolean esClientePreferenteODistribuidor',
        async_(() async {
      adapter.stub('POST', '/clubes/1/socios/activar', statusCode: 201, data: {});
      await ds.activarSocio(
        clubId: 1,
        activationPayload: 'ACT:1',
        esClientePreferenteODistribuidor: false,
      );
      expect(adapter.requests, hasLength(1));

      final sent = adapter.requests.single.data as Map;
      expect(sent['esClientePreferenteODistribuidor'], isFalse);
      expect(sent['esClientePreferenteODistribuidor'], isA<bool>());
    }));

    test('error se mapea', async_(() async {
      adapter.stub('POST', '/clubes/1/socios/activar', statusCode: 500, data: {});
      await expectLater(
        () => ds.activarSocio(
          clubId: 1,
          activationPayload: 'ACT:1',
          esClientePreferenteODistribuidor: false,
        ),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('getMembresiasPorUsuario', () {
    test('200 con lista parsea membresías', async_(() async {
      adapter.stub('GET', '/membresias/usuario/1', data: [
        {'id': 1, 'usuarioId': 1, 'clubId': 2, 'numeroSocio': 'S-1'},
      ]);
      final list = await ds.getMembresiasPorUsuario(1);
      expect(list, hasLength(1));
    }));

    test('200 con Map único lo envuelve en lista', async_(() async {
      adapter.stub('GET', '/membresias/usuario/2', data: {
        'id': 5,
        'usuarioId': 2,
        'clubId': 2,
        'numeroSocio': 'S-5',
      });
      final list = await ds.getMembresiasPorUsuario(2);
      expect(list, hasLength(1));
      expect(list.single.id, 5);
    }));

    test('200 con tipo inesperado devuelve lista vacía', async_(() async {
      adapter.stub('GET', '/membresias/usuario/3', data: '"texto"');
      final list = await ds.getMembresiasPorUsuario(3);
      expect(list, isEmpty);
    }));

    test('404 devuelve lista vacía', async_(() async {
      adapter.stub('GET', '/membresias/usuario/4', statusCode: 404, data: {});
      final list = await ds.getMembresiasPorUsuario(4);
      expect(list, isEmpty);
    }));

    test('500 lanza excepción', async_(() async {
      adapter.stub('GET', '/membresias/usuario/5', statusCode: 500, data: {});
      await expectLater(
        () => ds.getMembresiasPorUsuario(5),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('getAsistencias', () {
    test('200 parsea lista de asistencias', async_(() async {
      adapter.stub('GET', '/asistencias/socio/1', data: [
        {
          'id': 1,
          'membresiaId': 1,
          'clubId': 2,
          'fechaHora': '2024-01-01T10:00',
          'fechaDia': '2024-01-01',
          'estado': 'REGISTRADA',
        },
      ]);
      final list = await ds.getAsistencias(1);
      expect(list, hasLength(1));
    }));

    test('error se mapea', async_(() async {
      adapter.stub('GET', '/asistencias/socio/2', statusCode: 500, data: {});
      await expectLater(
        () => ds.getAsistencias(2),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('registrarAsistencia', () {
    test('200 con Map parsea AsistenciaResponse', async_(() async {
      adapter.stub('POST', '/asistencias/registrar', data: {
        'rachaActual': 3,
        'rachaMaxima': 5,
        'mensaje': 'Bien',
      });
      final resp = await ds.registrarAsistencia(
        membresiaId: 1,
        clubId: 2,
        latitud: -17.7,
        longitud: -63.1,
      );
      expect(resp.rachaActual, 3);
    }));

    test('sin body devuelve respuesta por defecto', async_(() async {
      adapter.stub('POST', '/asistencias/registrar', statusCode: 201, data: null);
      final resp = await ds.registrarAsistencia(
        membresiaId: 1,
        clubId: 2,
        latitud: -17.7,
        longitud: -63.1,
      );
      expect(resp.mensaje, 'Asistencia registrada correctamente');
    }));

    test('error de servidor se mapea', async_(() async {
      adapter.stub('POST', '/asistencias/registrar', statusCode: 500, data: {});
      await expectLater(
        () => ds.registrarAsistencia(
          membresiaId: 1,
          clubId: 2,
          latitud: 0,
          longitud: 0,
        ),
        throwsA(isA<AppException>()),
      );
    }));

    test('400 COMBO_REQUIRED se mapea a ComboRequiredException', async_(() async {
      adapter.stub('POST', '/asistencias/registrar', statusCode: 400, data: {
        'error': 'COMBO_REQUIRED',
        'message':
            'El socio no ha consumido ningún Combo antes de registrar asistencia.',
      });
      await expectLater(
        () => ds.registrarAsistencia(
          membresiaId: 1,
          clubId: 2,
          latitud: 0,
          longitud: 0,
        ),
        throwsA(
          isA<ComboRequiredException>().having(
            (e) => e.message,
            'message',
            contains('Combo'),
          ),
        ),
      );
    }));

    test('400 genérico no es ComboRequiredException', async_(() async {
      adapter.stub('POST', '/asistencias/registrar', statusCode: 400, data: {
        'success': false,
        'message': 'Ya existe una asistencia registrada para este socio hoy.',
      });
      await expectLater(
        () => ds.registrarAsistencia(
          membresiaId: 1,
          clubId: 2,
          latitud: 0,
          longitud: 0,
        ),
        throwsA(
          allOf(
            isA<ValidationException>(),
            isNot(isA<ComboRequiredException>()),
          ),
        ),
      );
    }));
  });

  group('registrarAsistenciaManual', () {
    test('éxito hace POST y parsea Attendance', async_(() async {
      adapter.stub('POST', '/membresias/1/asistencias', data: {
        'id': 1,
        'membresiaId': 1,
        'clubId': 1,
        'fechaHora': '2024-01-01',
        'fechaDia': '2024-01-01',
        'estado': 'MANUAL',
      });
      final attendance = await ds.registrarAsistenciaManual(
        membresiaId: 1,
        fecha: '2024-01-01',
        nota: 'Nota',
      );
      expect(attendance.estado, 'MANUAL');
    }));

    test('error se mapea', async_(() async {
      adapter.stub('POST', '/membresias/2/asistencias', statusCode: 500, data: {});
      await expectLater(
        () => ds.registrarAsistenciaManual(membresiaId: 2),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('getEstadoCombo', () {
    test('200 devuelve el Map original', async_(() async {
      adapter.stub('GET', '/membresias/1/estado-combo', data: {
        'haConsumidoCombo': true,
        'totalCombosConsumidos': 2,
      });
      final estado = await ds.getEstadoCombo(1);
      expect(estado['haConsumidoCombo'], isTrue);
    }));

    test('404 devuelve estado por defecto', async_(() async {
      adapter.stub('GET', '/membresias/2/estado-combo', statusCode: 404, data: {});
      final estado = await ds.getEstadoCombo(2);
      expect(estado['haConsumidoCombo'], isFalse);
      expect(estado['totalCombosConsumidos'], 0);
    }));

    test('500 lanza excepción', async_(() async {
      adapter.stub('GET', '/membresias/3/estado-combo', statusCode: 500, data: {});
      await expectLater(
        () => ds.getEstadoCombo(3),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('getArbolReferidos', () {
    test('200 parsea árbol con referidos anidados', async_(() async {
      adapter.stub('GET', '/membresias/1/arbol-referidos', data: {
        'membresiaId': 1,
        'numeroSocio': 'S-1',
        'nombreCompleto': 'Ana',
        'puntosAcumulados': 10,
        'estado': 'ACTIVO',
        'referidos': [
          {
            'membresiaId': 2,
            'numeroSocio': 'S-2',
            'nombreCompleto': 'Beto',
            'puntosAcumulados': 5,
            'estado': 'ACTIVO',
            'referidos': [],
          },
        ],
      });
      final arbol = await ds.getArbolReferidos(1);
      expect(arbol.referidos, hasLength(1));
      expect(arbol.referidos.single.nombreCompleto, 'Beto');
    }));

    test('error de servidor se mapea', async_(() async {
      adapter.stub('GET', '/membresias/2/arbol-referidos', statusCode: 500, data: {});
      await expectLater(
        () => ds.getArbolReferidos(2),
        throwsA(isA<AppException>()),
      );
    }));
  });
}
