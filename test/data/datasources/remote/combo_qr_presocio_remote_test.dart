import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/combo_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/pre_socio_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/qr_remote_data_source.dart';
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
  group('ComboRemoteDataSource', () {
    late _FakeAdapter adapter;
    late ComboRemoteDataSource ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = ComboRemoteDataSource(_buildDio(adapter));
    });

    test('getCombosByClub parsea lista', async_(() async {
      adapter.stub('GET', '/clubes/1/combos', data: [
        {'id': 1, 'clubId': 1, 'nombre': 'Combo 1', 'activo': true, 'items': []},
      ]);
      final combos = await ds.getCombosByClub(1);
      expect(combos, hasLength(1));
      expect(combos.first.nombre, 'Combo 1');
    }));

    test('getCombosByClub sin lista devuelve vacío', async_(() async {
      adapter.stub('GET', '/clubes/2/combos', data: {'unexpected': true});
      final combos = await ds.getCombosByClub(2);
      expect(combos, isEmpty);
    }));

    test('getCombosByClub error hace rethrow', async_(() async {
      adapter.stub('GET', '/clubes/3/combos', statusCode: 500, data: {});
      await expectLater(() => ds.getCombosByClub(3), throwsException);
    }));

    test('getCombo parsea un combo', async_(() async {
      adapter.stub('GET', '/clubes/1/combos/5', data: {
        'id': 5,
        'clubId': 1,
        'nombre': 'Combo X',
      });
      final combo = await ds.getCombo(1, 5);
      expect(combo.id, 5);
    }));

    test('createCombo hace POST con items', async_(() async {
      adapter.stub('POST', '/clubes/1/combos', data: {
        'id': 10,
        'clubId': 1,
        'nombre': 'Nuevo',
      });
      final combo = await ds.createCombo(
        1,
        nombre: 'Nuevo',
        descripcion: 'desc',
        imagenUrl: 'url',
        puntosValor: 3,
        precio: 35.0,
        items: [
          {'productoId': 1, 'cantidad': 2},
        ],
      );
      expect(combo.id, 10);
      expect(adapter.requests, hasLength(1));
      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['precio'], 35.0);
    }));

    test('updateCombo hace PUT', async_(() async {
      adapter.stub('PUT', '/clubes/1/combos/5', data: {
        'id': 5,
        'clubId': 1,
        'nombre': 'Actualizado',
      });
      final combo = await ds.updateCombo(
        1,
        5,
        nombre: 'Actualizado',
        precio: 40.0,
        items: const [],
      );
      expect(combo.nombre, 'Actualizado');
      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['precio'], 40.0);
    }));

    test('toggleCombo hace PATCH', async_(() async {
      adapter.stub('PATCH', '/clubes/1/combos/5/toggle', data: {
        'id': 5,
        'clubId': 1,
        'nombre': 'Combo',
        'activo': false,
      });
      final combo = await ds.toggleCombo(1, 5);
      expect(combo.activo, isFalse);
    }));

    test('deleteCombo hace DELETE', async_(() async {
      adapter.stub('DELETE', '/clubes/1/combos/5', statusCode: 200, data: {});
      await ds.deleteCombo(1, 5);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'DELETE');
    }));

    test('deleteCombo error hace rethrow', async_(() async {
      adapter.stub('DELETE', '/clubes/1/combos/9', statusCode: 500, data: {});
      await expectLater(() => ds.deleteCombo(1, 9), throwsException);
    }));
  });

  group('QRRemoteDataSourceImpl', () {
    late _FakeAdapter adapter;
    late QRRemoteDataSourceImpl ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = QRRemoteDataSourceImpl(_buildDio(adapter));
    });

    test('getSocioQR 200 parsea QrResponse con numeroSocio string', async_(() async {
      adapter.stub('GET', '/socios/me/qr', data: {
        'tipo': 'SOCIO',
        'qrPayload': 'SOCIO:CV-00000123',
        'numeroSocio': 'CV-00000123',
        'clubId': 1,
        'clubNombre': 'Club',
        'hubId': 1,
      });
      final qr = await ds.getSocioQR();
      expect(qr.tipo, 'SOCIO');
      expect(qr.qrPayload, 'SOCIO:CV-00000123');
      expect(qr.numeroSocio, 'CV-00000123');
    }));

    test('getSocioQR 401 lanza UnauthorizedException', async_(() async {
      adapter.stub('GET', '/socios/me/qr', statusCode: 401, data: {});
      await expectLater(
        () => ds.getSocioQR(),
        throwsA(isA<AppException>()),
      );
    }));

    test('getSocioQR 403 lanza ForbiddenException', async_(() async {
      adapter.stub('GET', '/socios/me/qr', statusCode: 403, data: {});
      await expectLater(
        () => ds.getSocioQR(),
        throwsA(isA<AppException>()),
      );
    }));

    test('getSocioQR error de servidor', async_(() async {
      adapter.stub('GET', '/socios/me/qr', statusCode: 500, data: {});
      await expectLater(
        () => ds.getSocioQR(),
        throwsA(isA<AppException>()),
      );
    }));

    test('validarSocioQR 200 quita prefijo SOCIO: y parsea respuesta',
        async_(() async {
      adapter.stub('POST', '/qr/validar-socio', data: {
        'membresiaId': 1,
        'numeroSocio': 'C1-0001',
        'valido': true,
      });
      final resp = await ds.validarSocioQR('SOCIO:C1-0001', 1);
      expect(resp.valido, isTrue);

      final sentBody = adapter.requests.last.data as Map;
      expect(sentBody['qr'], 'C1-0001');
    }));

    test('validarSocioQR sin prefijo envía tal cual', async_(() async {
      adapter.stub('POST', '/qr/validar-socio', data: {'valido': false});
      final resp = await ds.validarSocioQR('C2-0002', 1);
      expect(resp.valido, isFalse);
      final sentBody = adapter.requests.last.data as Map;
      expect(sentBody['qr'], 'C2-0002');
    }));

    test('validarSocioQR 400 con body Map devuelve respuesta inválida',
        async_(() async {
      adapter.stub('POST', '/qr/validar-socio', statusCode: 400, data: {
        'valido': false,
        'mensaje': 'QR no encontrado',
      });
      final resp = await ds.validarSocioQR('SOCIO:XX', 1);
      expect(resp.valido, isFalse);
      expect(resp.mensaje, 'QR no encontrado');
    }));

    test('validarSocioQR 500 lanza excepción', async_(() async {
      adapter.stub('POST', '/qr/validar-socio', statusCode: 500, data: {});
      await expectLater(
        () => ds.validarSocioQR('SOCIO:XX', 1),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('PreSocioRemoteDataSourceImpl', () {
    late _FakeAdapter adapter;
    late PreSocioRemoteDataSourceImpl ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = PreSocioRemoteDataSourceImpl(_buildDio(adapter));
    });

    test('crearPreSocio hace POST y parsea', async_(() async {
      adapter.stub('POST', '/clubes/1/prospectos', data: {
        'id': 1,
        'clubId': 1,
        'nombre': 'Pre Socio',
        'telefono': '123',
        'fechaCreacion': '2024-01-01',
        'estado': 'EN_SEGUIMIENTO',
      });
      final ps = await ds.crearPreSocio(
        clubId: 1,
        nombre: 'Pre Socio',
        telefono: '123',
        referidoPorMembresiaId: 5,
      );
      expect(ps.nombre, 'Pre Socio');
    }));

    test('crearPreSocio error se mapea', async_(() async {
      adapter.stub('POST', '/clubes/1/prospectos', statusCode: 500, data: {});
      await expectLater(
        () => ds.crearPreSocio(clubId: 1, nombre: 'X', telefono: '1'),
        throwsA(isA<AppException>()),
      );
    }));

    test('getPreSocios parsea lista', async_(() async {
      adapter.stub('GET', '/clubes/1/prospectos', data: [
        {
          'id': 1,
          'clubId': 1,
          'nombre': 'A',
          'telefono': '1',
          'fechaCreacion': '2024-01-01',
          'estado': 'EN_SEGUIMIENTO',
        },
      ]);
      final list = await ds.getPreSocios(1);
      expect(list, hasLength(1));
    }));

    test('getPreSocios 404 devuelve lista vacía', async_(() async {
      adapter.stub('GET', '/clubes/2/prospectos', statusCode: 404, data: {});
      final list = await ds.getPreSocios(2);
      expect(list, isEmpty);
    }));

    test('getPreSocios 500 lanza excepción', async_(() async {
      adapter.stub('GET', '/clubes/3/prospectos', statusCode: 500, data: {});
      await expectLater(
        () => ds.getPreSocios(3),
        throwsA(isA<AppException>()),
      );
    }));

    test('actualizarPreSocio hace PATCH', async_(() async {
      adapter.stub('PATCH', '/prospectos/1', statusCode: 200, data: {});
      await ds.actualizarPreSocio(1, 'CONVERTIDO');
      expect(adapter.requests, hasLength(1));
    }));

    test('actualizarPreSocio error se mapea', async_(() async {
      adapter.stub('PATCH', '/prospectos/1', statusCode: 500, data: {});
      await expectLater(
        () => ds.actualizarPreSocio(1, 'CONVERTIDO'),
        throwsA(isA<AppException>()),
      );
    }));

    test('crearMision hace POST y parsea', async_(() async {
      adapter.stub('POST', '/prospectos/1/misiones', data: {
        'id': 1,
        'prospectoId': 1,
        'nombre': 'Visitar 3 veces',
        'metaCantidad': 3,
        'progresoActual': 0,
        'completada': false,
      });
      final mision = await ds.crearMision(
        preSocioId: 1,
        nombre: 'Visitar 3 veces',
        metaCantidad: 3,
      );
      expect(mision.nombre, 'Visitar 3 veces');
    }));

    test('incrementarProgreso hace PATCH y parsea', async_(() async {
      adapter.stub('PATCH', '/misiones/1/progreso', data: {
        'id': 1,
        'prospectoId': 1,
        'nombre': 'M',
        'metaCantidad': 3,
        'progresoActual': 1,
        'completada': false,
      });
      final mision = await ds.incrementarProgreso(1);
      expect(mision.progresoActual, 1);
    }));

    test('eliminarMision hace DELETE', async_(() async {
      adapter.stub('DELETE', '/misiones/1', statusCode: 200, data: {});
      await ds.eliminarMision(1);
      expect(adapter.requests, hasLength(1));
    }));

    test('eliminarMision error se mapea', async_(() async {
      adapter.stub('DELETE', '/misiones/2', statusCode: 500, data: {});
      await expectLater(
        () => ds.eliminarMision(2),
        throwsA(isA<AppException>()),
      );
    }));
  });
}
