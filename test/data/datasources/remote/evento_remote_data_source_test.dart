import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/data/datasources/remote/evento_remote_data_source.dart';
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
      if (s.method == options.method &&
          options.uri.path.contains(s.pathContains)) {
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
    return ResponseBody.fromString('[]', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _FakeAdapter adapter;
  late EventoRemoteDataSourceImpl ds;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    ds = EventoRemoteDataSourceImpl(dio);
  });

  test('getEventos parsea lista general', () async {
    adapter.stub('GET', '/eventos', data: [
      {
        'id': 1,
        'nombre': 'Capacitación',
        'fechaEvento': '2026-09-01',
        'descripcion': 'Hoy',
      },
    ]);

    final eventos = await ds.getEventos();
    expect(eventos, hasLength(1));
    expect(eventos.first.fechaEvento, DateTime(2026, 9, 1));
  });

  test('getEventosByHub usa query hubId', () async {
    adapter.stub('GET', '/eventos', data: [
      {
        'id': 2,
        'hubId': 3,
        'nombre': 'Hub event',
        'fechaEvento': '2026-09-02',
        'descripcion': '',
      },
    ]);

    final eventos = await ds.getEventosByHub(3);
    expect(eventos, hasLength(1));
    expect(adapter.requests.single.queryParameters['hubId'], 3);
  });

  test('getEventosByClub usa query clubId', () async {
    adapter.stub('GET', '/eventos', data: [
      {
        'id': 3,
        'clubId': 7,
        'nombre': 'Club event',
        'fechaEvento': '2026-09-03',
        'descripcion': '',
      },
    ]);

    final eventos = await ds.getEventosByClub(7);
    expect(eventos, hasLength(1));
    expect(adapter.requests.single.queryParameters['clubId'], 7);
  });

  test('ignora registros con fecha inválida', () async {
    adapter.stub('GET', '/eventos', data: [
      {
        'id': 4,
        'nombre': 'Válido',
        'fechaEvento': '2026-09-04',
        'descripcion': '',
      },
      {
        'id': 5,
        'nombre': 'Inválido',
        'fechaEvento': null,
        'descripcion': '',
      },
    ]);

    final eventos = await ds.getEventos();
    expect(eventos, hasLength(1));
    expect(eventos.first.id, 4);
  });
}
