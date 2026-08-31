import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/data/datasources/remote/compras_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/evento_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/report_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/resumen_mensual_report_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/sabor_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/support_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/ventas_diarias_report_data_source.dart';
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
  group('SaborRemoteDataSource', () {
    late _FakeAdapter adapter;
    late SaborRemoteDataSource ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = SaborRemoteDataSource(_buildDio(adapter));
    });

    test('getSaboresDeProductoEnClub 200 parsea lista', async_(() async {
      adapter.stub('GET', '/clubes/1/productos/2/sabores', data: [
        {'id': 1, 'nombre': 'Vainilla', 'disponible': true},
      ]);
      final sabores = await ds.getSaboresDeProductoEnClub(1, 2);
      expect(sabores, hasLength(1));
      expect(sabores.first.disponible, isTrue);
    }));

    test('getSaboresDeProductoEnClub sin lista devuelve vacío', async_(() async {
      adapter.stub('GET', '/clubes/1/productos/3/sabores', data: {'x': 1});
      final sabores = await ds.getSaboresDeProductoEnClub(1, 3);
      expect(sabores, isEmpty);
    }));

    test('getSaboresDeProductoEnClub error hace rethrow', async_(() async {
      adapter.stub('GET', '/clubes/1/productos/9/sabores', statusCode: 500, data: {});
      await expectLater(
        () => ds.getSaboresDeProductoEnClub(1, 9),
        throwsException,
      );
    }));

    test('toggleSaborEnClub hace PATCH y parsea Sabor', async_(() async {
      adapter.stub('PATCH', '/clubes/1/productos/2/sabores/3/toggle', data: {
        'id': 3,
        'nombre': 'Chocolate',
        'disponible': false,
      });
      final sabor = await ds.toggleSaborEnClub(1, 2, 3);
      expect(sabor.nombre, 'Chocolate');
      expect(sabor.disponible, isFalse);
    }));

    test('toggleSaborEnClub error hace rethrow', async_(() async {
      adapter.stub('PATCH', '/clubes/1/productos/2/sabores/9/toggle',
          statusCode: 500, data: {});
      await expectLater(
        () => ds.toggleSaborEnClub(1, 2, 9),
        throwsException,
      );
    }));
  });

  group('ComprasRemoteDataSourceImpl', () {
    late _FakeAdapter adapter;
    late ComprasRemoteDataSourceImpl ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = ComprasRemoteDataSourceImpl(_buildDio(adapter));
    });

    test('getComprasPorMembresia parsea lista', async_(() async {
      adapter.stub('GET', '/membresias/1/compras', data: [
        {
          'id': 1,
          'membresiaId': 1,
          'clubId': 2,
          'descripcion': 'Compra A',
          'monto': 25.5,
          'fecha': '2024-01-01',
        },
      ]);
      final compras = await ds.getComprasPorMembresia(1);
      expect(compras, hasLength(1));
      expect(compras.first.monto, 25.5);
    }));

    test('getComprasPorMembresia 404 devuelve lista vacía', async_(() async {
      adapter.stub('GET', '/membresias/2/compras', statusCode: 404, data: {});
      final compras = await ds.getComprasPorMembresia(2);
      expect(compras, isEmpty);
    }));

    test('getComprasPorMembresia error distinto de 404 lanza excepción',
        async_(() async {
      adapter.stub('GET', '/membresias/3/compras', statusCode: 500, data: {
        'message': 'Fallo interno',
      });
      await expectLater(
        () => ds.getComprasPorMembresia(3),
        throwsA(isA<Exception>()),
      );
    }));

    test('registrarCompra hace POST y parsea la compra creada', async_(() async {
      adapter.stub('POST', '/membresias/1/compras', statusCode: 201, data: {
        'id': 10,
        'membresiaId': 1,
        'clubId': 2,
        'descripcion': 'Nueva',
        'monto': 15.0,
        'fecha': '2024-02-01',
        'registradaPorHostId': 7,
      });
      final compra = await ds.registrarCompra(
        membresiaId: 1,
        clubId: 2,
        descripcion: 'Nueva',
        monto: 15.0,
        fecha: '2024-02-01',
      );
      expect(compra.id, 10);
      expect(compra.registradaPorHostId, 7);
    }));

    test('registrarCompra error lanza excepción con mensaje', async_(() async {
      adapter.stub('POST', '/membresias/1/compras', statusCode: 500, data: {
        'message': 'No se pudo registrar',
      });
      await expectLater(
        () => ds.registrarCompra(
          membresiaId: 1,
          clubId: 2,
          descripcion: 'X',
          monto: 1.0,
          fecha: '2024-01-01',
        ),
        throwsA(isA<Exception>()),
      );
    }));
  });

  group('EventoRemoteDataSourceImpl', () {
    late _FakeAdapter adapter;
    late EventoRemoteDataSourceImpl ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = EventoRemoteDataSourceImpl(_buildDio(adapter));
    });

    test('getEventos 200 parsea lista', async_(() async {
      adapter.stub('GET', '/eventos', data: [
        {
          'id': 1,
          'nombre': 'Evento 1',
          'fechaEvento': '2024-05-01',
          'descripcion': 'Desc',
        },
      ]);
      final eventos = await ds.getEventos();
      expect(eventos, hasLength(1));
      expect(eventos.first.nombre, 'Evento 1');
    }));

    test('getEventos error lanza excepción', async_(() async {
      adapter.stub('GET', '/eventos', statusCode: 500, data: {});
      await expectLater(() => ds.getEventos(), throwsException);
    }));

    test('getEventosByHub filtra por hubId y parsea', async_(() async {
      adapter.stub('GET', '/eventos', data: [
        {
          'id': 2,
          'hubId': 5,
          'nombre': 'Evento Hub',
          'fechaEvento': '2024-05-02T10:00:00',
          'descripcion': 'Desc',
        },
      ]);
      final eventos = await ds.getEventosByHub(5);
      expect(eventos, hasLength(1));
      expect(adapter.requests.last.queryParameters['hubId'], 5);
    }));

    test('getEventosByHub error lanza excepción', async_(() async {
      adapter.stub('GET', '/eventos', statusCode: 500, data: {});
      await expectLater(() => ds.getEventosByHub(1), throwsException);
    }));

    test('getEventosByClub filtra por clubId y parsea', async_(() async {
      adapter.stub('GET', '/eventos', data: [
        {
          'id': 3,
          'clubId': 9,
          'nombre': 'Evento Club',
          'fecha': 1700000000000,
          'descripcion': 'Desc',
        },
      ]);
      final eventos = await ds.getEventosByClub(9);
      expect(eventos, hasLength(1));
      expect(adapter.requests.last.queryParameters['clubId'], 9);
    }));

    test('getEventosByClub error lanza excepción', async_(() async {
      adapter.stub('GET', '/eventos', statusCode: 500, data: {});
      await expectLater(() => ds.getEventosByClub(1), throwsException);
    }));
  });

  group('ReportRemoteDataSource', () {
    late _FakeAdapter adapter;
    late ReportRemoteDataSource ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = ReportRemoteDataSource(_buildDio(adapter));
    });

    test('descargarReporte 200 devuelve bytes', async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/1/descargar', data: 'PDFDATA');
      final bytes = await ds.descargarReporte(
        clubId: 1,
        fechaInicio: DateTime(2024, 1, 1),
        fechaFin: DateTime(2024, 1, 31),
        formato: 'PDF',
      );
      expect(bytes, isNotEmpty);

      final sentUri = adapter.requests.last.uri;
      expect(sentUri.queryParameters['fechaInicio'], '2024-01-01');
      expect(sentUri.queryParameters['fechaFin'], '2024-01-31');
    }));

    test('descargarReporte con error lanza DioException con mensaje mapeado',
        async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/2/descargar',
          statusCode: 403, data: '');
      await expectLater(
        () => ds.descargarReporte(
          clubId: 2,
          fechaInicio: DateTime(2024, 1, 1),
          fechaFin: DateTime(2024, 1, 2),
          formato: 'PDF',
        ),
        throwsA(isA<DioException>()),
      );
    }));

    test('descargarReporte con 404 usa mensaje de recurso no encontrado',
        async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/3/descargar',
          statusCode: 404, data: '');
      try {
        await ds.descargarReporte(
          clubId: 3,
          fechaInicio: DateTime(2024, 1, 1),
          fechaFin: DateTime(2024, 1, 2),
          formato: 'PDF',
        );
        fail('debía lanzar');
      } catch (e) {
        expect(e, isA<DioException>());
        expect((e as DioException).message, contains('No se encontró'));
      }
    }));
  });

  group('ResumenMensualReportDataSource', () {
    late _FakeAdapter adapter;
    late ResumenMensualReportDataSource ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = ResumenMensualReportDataSource(_buildDio(adapter));
    });

    test('obtenerReporte 200 parsea ResumenMensualVentas', async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/1/resumen-mensual', data: {
        'clubId': 1,
        'anio': 2024,
        'mes': 3,
        'nombreMes': 'Marzo',
        'resumen': {'totalVentas': 5, 'totalIngresosBs': 50.0},
        'ventasPorDia': [],
        'topProductos': [],
      });
      final resumen = await ds.obtenerReporte(clubId: 1, anio: 2024, mes: 3);
      expect(resumen.clubId, 1);
    }));

    test('obtenerReporte con error lanza DioException', async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/2/resumen-mensual',
          statusCode: 401, data: {});
      await expectLater(
        () => ds.obtenerReporte(clubId: 2, anio: 2024, mes: 1),
        throwsA(isA<DioException>()),
      );
    }));

    test('descargarReporte 200 devuelve bytes', async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/1/resumen-mensual/descargar',
          data: 'EXCELDATA');
      final bytes = await ds.descargarReporte(
        clubId: 1,
        anio: 2024,
        mes: 3,
        formato: 'EXCEL',
      );
      expect(bytes, isNotEmpty);
    }));

    test('descargarReporte con error lanza DioException', async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/2/resumen-mensual/descargar',
          statusCode: 404, data: '');
      await expectLater(
        () => ds.descargarReporte(clubId: 2, anio: 2024, mes: 1, formato: 'PDF'),
        throwsA(isA<DioException>()),
      );
    }));
  });

  group('VentasDiariasReportDataSource', () {
    late _FakeAdapter adapter;
    late VentasDiariasReportDataSource ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = VentasDiariasReportDataSource(_buildDio(adapter));
    });

    test('obtenerReporte 200 parsea VentasDiariasReporte', async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/1/ventas-diarias', data: {
        'clubId': 1,
        'fecha': '2024-03-01',
        'resumen': {'fecha': '2024-03-01'},
        'filas': [],
      });
      final reporte = await ds.obtenerReporte(
        clubId: 1,
        fecha: DateTime(2024, 3, 1),
      );
      expect(reporte.clubId, 1);

      final sentUri = adapter.requests.last.uri;
      expect(sentUri.queryParameters['fecha'], '2024-03-01');
    }));

    test('obtenerReporte con error 500 usa mensaje de servidor', async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/2/ventas-diarias',
          statusCode: 500, data: {});
      try {
        await ds.obtenerReporte(clubId: 2, fecha: DateTime(2024, 3, 1));
        fail('debía lanzar');
      } catch (e) {
        expect(e, isA<DioException>());
        expect((e as DioException).message, contains('servidor'));
      }
    }));

    test('obtenerReporte usa mensaje del backend cuando viene en data',
        async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/3/ventas-diarias',
          statusCode: 400, data: {'data': 'Fecha inválida'});
      try {
        await ds.obtenerReporte(clubId: 3, fecha: DateTime(2024, 3, 1));
        fail('debía lanzar');
      } catch (e) {
        expect(e, isA<DioException>());
        expect((e as DioException).message, 'Fecha inválida');
      }
    }));

    test('descargarReporte 200 devuelve bytes', async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/1/ventas-diarias/descargar',
          data: 'BYTES');
      final bytes = await ds.descargarReporte(
        clubId: 1,
        fecha: DateTime(2024, 3, 1),
        formato: 'PDF',
      );
      expect(bytes, isNotEmpty);
    }));

    test('descargarReporte con error lanza DioException', async_(() async {
      adapter.stub('GET', '/reportes/anfitrion/2/ventas-diarias/descargar',
          statusCode: 403, data: '');
      await expectLater(
        () => ds.descargarReporte(
          clubId: 2,
          fecha: DateTime(2024, 3, 1),
          formato: 'PDF',
        ),
        throwsA(isA<DioException>()),
      );
    }));
  });

  group('SupportRemoteDataSourceImpl', () {
    late _FakeAdapter adapter;
    late SupportRemoteDataSourceImpl ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = SupportRemoteDataSourceImpl(_buildDio(adapter));
    });

    test('createTicket éxito no lanza', async_(() async {
      adapter.stub('POST', '/soporte-tickets', statusCode: 201, data: {});
      await ds.createTicket(
        tipoSolicitud: 'BUG',
        asunto: 'Falla',
        mensaje: 'Detalle',
      );
      expect(adapter.requests, hasLength(1));
    }));

    test('createTicket solo envía tipoSolicitud, asunto y mensaje', async_(() async {
      adapter.stub('POST', '/soporte-tickets', statusCode: 201, data: {});
      await ds.createTicket(
        tipoSolicitud: 'BUG',
        asunto: 'Falla',
        mensaje: 'Detalle',
      );
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.first.data, {
        'tipoSolicitud': 'BUG',
        'asunto': 'Falla',
        'mensaje': 'Detalle',
      });
    }));

    test('createTicket con error mapea a AppException', async_(() async {
      adapter.stub('POST', '/soporte-tickets', statusCode: 500, data: {});
      await expectLater(
        () => ds.createTicket(
          tipoSolicitud: 'BUG',
          asunto: 'Falla',
          mensaje: 'Detalle',
        ),
        throwsException,
      );
    }));

    test('getMyTickets usa GET /soporte-tickets/mios sin usuarioId en URL',
        async_(() async {
      adapter.stub('GET', '/soporte-tickets/mios', data: [
        {
          'id': 1,
          'usuarioId': 1,
          'tipoSolicitud': 'BUG',
          'asunto': 'A',
          'mensaje': 'M',
          'estado': 'abierto',
          'fechaCreacion': '2024-01-01T00:00:00',
        },
      ]);
      final tickets = await ds.getMyTickets();
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.first.uri.path, contains('/soporte-tickets/mios'));
      expect(adapter.requests.first.uri.path, isNot(contains('usuario')));
      expect(tickets, hasLength(1));
      expect(tickets.first.estado, 'ABIERTO');
    }));

    test('getMyTickets con envoltorio content', async_(() async {
      adapter.stub('GET', '/soporte-tickets/mios', data: {
        'content': [
          {
            'id': 2,
            'usuarioId': 2,
            'tipoSolicitud': 'DUDA',
            'asunto': 'B',
            'mensaje': 'M2',
            'estado': 'CERRADO',
            'fechaCreacion': '2024-01-02T00:00:00',
          },
        ],
      });
      final tickets = await ds.getMyTickets();
      expect(tickets, hasLength(1));
    }));

    test('getMyTickets lista vacía retorna []', async_(() async {
      adapter.stub('GET', '/soporte-tickets/mios', data: []);
      final tickets = await ds.getMyTickets();
      expect(tickets, isEmpty);
    }));

    test('getMyTickets parsea respuestaAdmin y estado RESUELTO', async_(() async {
      adapter.stub('GET', '/soporte-tickets/mios', data: [
        {
          'id': 3,
          'usuarioId': 5,
          'tipoSolicitud': 'Consulta',
          'asunto': 'Ayuda',
          'mensaje': 'Detalle',
          'estado': 'RESUELTO',
          'fechaCreacion': '2024-03-01T00:00:00',
          'respuestaAdmin': 'Gracias por contactarnos',
        },
      ]);
      final tickets = await ds.getMyTickets();
      expect(tickets, hasLength(1));
      expect(tickets.first.estado, 'RESUELTO');
      expect(tickets.first.respuestaAdmin, 'Gracias por contactarnos');
    }));

    test('getMyTickets con error lanza excepción', async_(() async {
      adapter.stub('GET', '/soporte-tickets/mios', statusCode: 500, data: {});
      await expectLater(
        () => ds.getMyTickets(),
        throwsException,
      );
    }));
  });
}
