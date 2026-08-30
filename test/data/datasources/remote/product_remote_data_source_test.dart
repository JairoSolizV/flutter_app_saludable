import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_test/flutter_test.dart';

class _Stub {
  _Stub(this.method, this.pathContains, this.statusCode, this.data,
      this.queryContains);
  final String method;
  final String pathContains;
  final int statusCode;
  final dynamic data;
  final Map<String, String>? queryContains;
}

class _FakeAdapter implements HttpClientAdapter {
  final List<_Stub> _stubs = [];
  final List<RequestOptions> requests = [];

  void stub(
    String method,
    String pathContains, {
    int statusCode = 200,
    dynamic data,
    Map<String, String>? queryContains,
  }) {
    _stubs.add(
        _Stub(method.toUpperCase(), pathContains, statusCode, data, queryContains));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    for (final s in _stubs) {
      if (s.method != options.method) continue;
      if (!options.uri.path.contains(s.pathContains)) continue;
      if (s.queryContains != null) {
        final matches = s.queryContains!.entries.every(
          (e) => options.uri.queryParameters[e.key] == e.value,
        );
        if (!matches) continue;
      }
      final body = s.data is String ? s.data : jsonEncode(s.data);
      return ResponseBody.fromString(
        body,
        s.statusCode,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
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
  late ProductRemoteDataSourceImpl ds;

  setUp(() {
    adapter = _FakeAdapter();
    ds = ProductRemoteDataSourceImpl(_buildDio(adapter));
  });

  group('getProducts', () {
    test('combina productos globales y locales desde listas', async_(() async {
      adapter.stub('GET', '/productos', data: [
        {'id': 1, 'nombre': 'Global 1', 'clubCreadorId': null},
      ], queryContains: {'tipo': 'GLOBAL'});
      adapter.stub('GET', '/productos', data: [
        {'id': 2, 'nombre': 'Local 1', 'clubCreadorId': 5, 'disponible': true},
      ], queryContains: {'tipo': 'LOCAL'});

      final products = await ds.getProducts(hubId: 1, clubId: 5);
      expect(products, hasLength(2));
      expect(products.map((p) => p.tipo).toSet(), {'GLOBAL', 'LOCAL'});
    }));

    test('preserva revisión e ingredientes en LOCAL', async_(() async {
      adapter.stub('GET', '/productos', data: [
        {'id': 1, 'nombre': 'Global 1', 'tipo': 'GLOBAL'},
      ], queryContains: {'tipo': 'GLOBAL'});
      adapter.stub('GET', '/productos', data: [
        {
          'id': 6,
          'nombre': 'Frappe',
          'descripcion': 'Batido',
          'ingredientes': 'leche, hielo',
          'tipo': 'LOCAL',
          'estadoAprobacion': 'RECHAZADO',
          'comentarioRevision': 'falta info',
          'revisadoPorNombre': 'Admin Hub',
          'revisadoAt': '2026-08-29T18:30:00',
          'puntosValor': 10,
          'clubCreadorId': 3,
        },
      ], queryContains: {'tipo': 'LOCAL'});

      final products = await ds.getProducts(hubId: 1, clubId: 3);
      final local = products.firstWhere((p) => p.tipo == 'LOCAL');
      expect(local.comentarioRevision, 'falta info');
      expect(local.ingredientes, 'leche, hielo');
      expect(local.revisadoPorNombre, 'Admin Hub');
      expect(local.revisadoAt, isNotNull);
      expect(local.estadoAprobacion, 'RECHAZADO');
    }));

    test('parsea gruposOpciones del ANFITRION', async_(() async {
      adapter.stub('GET', '/productos', data: [], queryContains: {'tipo': 'GLOBAL'});
      adapter.stub('GET', '/productos', data: [
        {
          'id': 6,
          'nombre': 'Batido',
          'tipo': 'LOCAL',
          'estadoAprobacion': 'PENDIENTE',
          'clubCreadorId': 3,
          'gruposOpciones': [
            {
              'id': 1,
              'nombre': 'Sabores',
              'orden': 0,
              'minSelecciones': 1,
              'maxSelecciones': 2,
              'permiteRepetir': true,
              'opciones': [
                {'id': 10, 'nombre': 'Frutilla', 'orden': 0, 'activo': true},
                {'id': 11, 'nombre': 'Vainilla', 'orden': 1, 'activo': true},
              ],
            },
          ],
        },
      ], queryContains: {'tipo': 'LOCAL'});

      final products = await ds.getProducts(hubId: 1, clubId: 3);
      final local = products.first;
      expect(local.optionGroups, hasLength(1));
      expect(local.optionGroups!.first.options.map((o) => o.name),
          ['Frutilla', 'Vainilla']);
    }));

    test('extrae de envoltorio content y data y productos', async_(() async {
      adapter.stub('GET', '/productos', data: {
        'content': [
          {'id': 1, 'nombre': 'G'},
        ],
      }, queryContains: {'tipo': 'GLOBAL'});
      adapter.stub('GET', '/productos', data: {
        'productos': [
          {'id': 2, 'nombre': 'L'},
        ],
      }, queryContains: {'tipo': 'LOCAL'});

      final products = await ds.getProducts(hubId: 1, clubId: 5);
      expect(products, hasLength(2));
    }));

    test('respuesta sin 200 en alguno lanza ServerException', async_(() async {
      adapter.stub('GET', '/productos',
          statusCode: 500, data: {}, queryContains: {'tipo': 'GLOBAL'});
      adapter.stub('GET', '/productos', data: [], queryContains: {'tipo': 'LOCAL'});

      await expectLater(
        () => ds.getProducts(hubId: 1, clubId: 5),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('getAvailableProductsByClub', () {
    test('200 con lista directa', async_(() async {
      adapter.stub('GET', '/productos', data: [
        {'id': 1, 'nombre': 'P1', 'disponible': true},
      ]);
      final products = await ds.getAvailableProductsByClub(5);
      expect(products, hasLength(1));
      expect(products.first.available, isTrue);
    }));

    test('200 con envoltorio content', async_(() async {
      adapter.stub('GET', '/productos', data: {
        'content': [
          {'id': 1, 'nombre': 'P1', 'disponible': false},
        ],
      });
      final products = await ds.getAvailableProductsByClub(5);
      expect(products.first.available, isFalse);
    }));

    test('200 con envoltorio data', async_(() async {
      adapter.stub('GET', '/productos', data: {
        'data': [
          {'id': 2, 'nombre': 'P2'},
        ],
      });
      final products = await ds.getAvailableProductsByClub(5);
      expect(products, hasLength(1));
      // disponible ausente => true por defecto en este endpoint
      expect(products.first.available, isTrue);
    }));

    test('401 lanza UnauthorizedException', async_(() async {
      adapter.stub('GET', '/productos', statusCode: 401, data: {});
      await expectLater(
        () => ds.getAvailableProductsByClub(5),
        throwsA(isA<AppException>()),
      );
    }));

    test('403 lanza ForbiddenException', async_(() async {
      adapter.stub('GET', '/productos', statusCode: 403, data: {});
      await expectLater(
        () => ds.getAvailableProductsByClub(5),
        throwsA(isA<AppException>()),
      );
    }));

    test('500 lanza ServerException', async_(() async {
      adapter.stub('GET', '/productos', statusCode: 500, data: {});
      await expectLater(
        () => ds.getAvailableProductsByClub(5),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('toggleProductAvailability', () {
    test('éxito hace PATCH', async_(() async {
      adapter.stub('PATCH', '/clubes/1/productos/2/toggle', data: {});
      await ds.toggleProductAvailability(1, '2');
      expect(adapter.requests, hasLength(1));
    }));

    test('id inválido lanza ValidationException sin llamar a la red',
        async_(() async {
      await expectLater(
        () => ds.toggleProductAvailability(1, 'abc'),
        throwsA(isA<ValidationException>()),
      );
      expect(adapter.requests, isEmpty);
    }));

    test('error del servidor se mapea', async_(() async {
      adapter.stub('PATCH', '/clubes/1/productos/2/toggle',
          statusCode: 500, data: {});
      await expectLater(
        () => ds.toggleProductAvailability(1, '2'),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('createProduct', () {
    test('hace POST con datos del producto', async_(() async {
      adapter.stub('POST', '/productos', statusCode: 201, data: {});
      await ds.createProduct(
        Product(id: '1', name: 'P', description: 'D'),
        3,
      );
      expect(adapter.requests, hasLength(1));
    }));

    test('error se mapea a AppException', async_(() async {
      adapter.stub('POST', '/productos', statusCode: 500, data: {});
      await expectLater(
        () => ds.createProduct(Product(id: '1', name: 'P', description: 'D'), 3),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('createProductProposal', () {
    test('éxito no lanza', async_(() async {
      adapter.stub('POST', '/productos', statusCode: 201, data: {});
      await ds.createProductProposal(
        hubId: 1,
        nombre: 'N',
        descripcion: 'D',
        ingredientes: 'I',
        puntosValor: 5,
        imagenUrl: 'http://x.png',
      );
      expect(adapter.requests, hasLength(1));
      final data = adapter.requests.single.data as Map;
      expect(data.containsKey('gruposOpciones'), isFalse);
    }));

    test('incluye gruposOpciones cuando hay definición', async_(() async {
      adapter.stub('POST', '/productos', statusCode: 201, data: {});
      await ds.createProductProposal(
        hubId: 1,
        nombre: 'Batido',
        descripcion: 'D',
        ingredientes: 'I',
        puntosValor: 10,
        optionGroups: [
          ProductOptionGroup(
            name: 'Sabores',
            orden: 0,
            minSelections: 1,
            maxSelections: null,
            allowRepeat: true,
            options: [
              ProductOption(name: 'Frutilla', orden: 0),
              ProductOption(name: 'Chocolate', orden: 1),
            ],
          ),
        ],
      );
      final data = adapter.requests.single.data as Map;
      expect(data['gruposOpciones'], isA<List>());
      final group = (data['gruposOpciones'] as List).first as Map;
      expect(group['nombre'], 'Sabores');
      expect(group['maxSelecciones'], isNull);
      expect(group['permiteRepetir'], isTrue);
      expect((group['opciones'] as List).length, 2);
    }));

    test('sin imagenUrl no la incluye pero funciona', async_(() async {
      adapter.stub('POST', '/productos', statusCode: 200, data: {});
      await ds.createProductProposal(
        hubId: 1,
        nombre: 'N',
        descripcion: 'D',
        ingredientes: 'I',
        puntosValor: 5,
      );
      expect(adapter.requests, hasLength(1));
    }));

    test('status inesperado lanza ServerException', async_(() async {
      adapter.stub('POST', '/productos', statusCode: 500, data: {});
      await expectLater(
        () => ds.createProductProposal(
          hubId: 1,
          nombre: 'N',
          descripcion: 'D',
          ingredientes: 'I',
          puntosValor: 5,
        ),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('updateProduct', () {
    test('hace PUT con payload completo de propuesta', async_(() async {
      adapter.stub('PUT', '/productos/1', statusCode: 200, data: {});
      await ds.updateProduct(Product(
        id: '1',
        name: 'Frappe',
        description: 'Batido',
        ingredientes: 'leche, hielo',
        puntosValor: 12,
        imageUrl: '/api/productos/imagenes/a.png',
        active: true,
        tipo: 'LOCAL',
        estadoAprobacion: 'RECHAZADO',
      ));
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'PUT');
      final data = adapter.requests.single.data as Map;
      expect(data['nombre'], 'Frappe');
      expect(data['descripcion'], 'Batido');
      expect(data['ingredientes'], 'leche, hielo');
      expect(data['puntosValor'], 12);
      expect(data['imagenUrl'], '/api/productos/imagenes/a.png');
      expect(data['activo'], isTrue);
    }));

    test('manda gruposOpciones completos incluyendo max null', async_(() async {
      adapter.stub('PUT', '/productos/1', statusCode: 200, data: {});
      await ds.updateProduct(Product(
        id: '1',
        name: 'Batido',
        description: 'D',
        ingredientes: 'I',
        puntosValor: 10,
        optionGroups: [
          ProductOptionGroup(
            name: 'Sabores',
            orden: 0,
            minSelections: 1,
            maxSelections: null,
            allowRepeat: true,
            options: [
              ProductOption(id: 10, name: 'Frutilla', orden: 0),
            ],
          ),
        ],
      ));
      final data = adapter.requests.single.data as Map;
      expect(data.containsKey('gruposOpciones'), isTrue);
      expect((data['gruposOpciones'] as List).first['maxSelecciones'], isNull);
      expect((data['gruposOpciones'] as List).first['nombre'], 'Sabores');
    }));

    test('omite gruposOpciones si optionGroups es null (preservar)', async_(() async {
      adapter.stub('PUT', '/productos/1', statusCode: 200, data: {});
      await ds.updateProduct(Product(id: '1', name: 'P', description: 'D'));
      final data = adapter.requests.single.data as Map;
      expect(data.containsKey('imagenUrl'), isFalse);
      expect(data.containsKey('ingredientes'), isFalse);
      expect(data.containsKey('gruposOpciones'), isFalse);
    }));

    test('error se mapea', async_(() async {
      adapter.stub('PUT', '/productos/1', statusCode: 500, data: {});
      await expectLater(
        () => ds.updateProduct(Product(id: '1', name: 'P', description: 'D')),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('reenviarProducto', () {
    test('llama PATCH /productos/{id}/reenviar', async_(() async {
      adapter.stub('PATCH', '/productos/6/reenviar', statusCode: 200, data: {
        'id': 6,
        'nombre': 'Frappe',
        'estadoAprobacion': 'PENDIENTE',
        'tipo': 'LOCAL',
        'comentarioRevision': 'falta info',
      });
      final product = await ds.reenviarProducto('6');
      expect(adapter.requests.single.method, 'PATCH');
      expect(adapter.requests.single.uri.path, contains('/productos/6/reenviar'));
      expect(product.estadoAprobacion, 'PENDIENTE');
      expect(product.comentarioRevision, 'falta info');
    }));

    test('error se mapea', async_(() async {
      adapter.stub('PATCH', '/productos/6/reenviar',
          statusCode: 400, data: {'message': 'Solo se puede reenviar un producto RECHAZADO'});
      await expectLater(
        () => ds.reenviarProducto('6'),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('deleteProduct', () {
    test('no llama /desactivar ni DELETE', async_(() async {
      await expectLater(
        () => ds.deleteProduct('1'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(adapter.requests, isEmpty);
    }));
  });
}
