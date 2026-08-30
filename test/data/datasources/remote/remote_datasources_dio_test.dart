import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/membresia_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/support_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_test/flutter_test.dart';

class _Stub {
  _Stub(this.method, this.pathContains, this.statusCode, this.data);
  final String method;
  final String pathContains;
  final int statusCode;
  final dynamic data;
}

/// Fake [HttpClientAdapter] que responde según reglas simples de
/// método + subcadena de la ruta, sin tocar la red real.
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

void main() {
  group('OrderRemoteDataSourceImpl', () {
    late _FakeAdapter adapter;
    late OrderRemoteDataSourceImpl ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = OrderRemoteDataSourceImpl(_buildDio(adapter));
    });

    test('getOrdersByClub parsea lista de pedidos', async_(() async {
      adapter.stub('GET', '/pedidos/club/5', data: [
        {'id': 1, 'clubId': 5, 'estado': 'PENDIENTE'},
        {'id': 2, 'clubId': 5, 'estado': 'LISTO'},
      ]);

      final orders = await ds.getOrdersByClub(5);

      expect(orders, hasLength(2));
      expect(orders.first['estado'], 'PENDIENTE');
    }));

    test('getOrdersByClub soporta respuesta envuelta en "content"', async_(() async {
      adapter.stub('GET', '/pedidos/club/9', data: {
        'content': [
          {'id': 10, 'clubId': 9},
        ],
      });

      final orders = await ds.getOrdersByClub(9);

      expect(orders, hasLength(1));
      expect(orders.first['id'], 10);
    }));

    test('getOrdersBySocio parsea lista de pedidos del socio', async_(() async {
      adapter.stub('GET', '/pedidos/socio/7', data: [
        {'id': 3, 'membresiaId': 7},
      ]);

      final orders = await ds.getOrdersBySocio(7);

      expect(orders, hasLength(1));
      expect(orders.first['membresiaId'], 7);
    }));

    test('getOrdersByClubPage parsea PagedResult', async_(() async {
      adapter.stub('GET', '/pedidos/club/5/paginados', data: {
        'content': [
          {'id': 1, 'clubId': 5},
          {'id': 2, 'clubId': 5},
        ],
        'page': 0,
        'size': 20,
        'totalElements': 2,
        'totalPages': 1,
        'first': true,
        'last': true,
        'hasNext': false,
        'hasPrevious': false,
      });

      final page = await ds.getOrdersByClubPage(5);

      expect(page.content, hasLength(2));
      expect(page.totalElements, 2);
      expect(page.first, isTrue);
    }));

    test('updateOrderStatus envía PATCH con estado y tiempo estimado',
        async_(() async {
      adapter.stub('PATCH', '/pedidos/10/estado', statusCode: 200, data: {});

      await ds.updateOrderStatus(10, 'LISTO', estimatedTime: 15);

      final sent = adapter.requests.last;
      expect(sent.method, 'PATCH');
      expect(sent.queryParameters['estado'], 'LISTO');
      expect(sent.queryParameters['tiempoEstimadoMinutos'], 15);
    }));

    test('createCounterSale con items vacíos lanza sin llamar a la red',
        async_(() async {
      await expectLater(
        () => ds.createCounterSale(
          clubId: 1,
          tipoPago: 'EFECTIVO',
          items: const [],
        ),
        throwsException,
      );
      expect(adapter.requests, isEmpty);
    }));

    test('createCounterSale exitoso hace POST a /pedidos/mostrador',
        async_(() async {
      adapter.stub('POST', '/pedidos/mostrador', statusCode: 201, data: {});

      await ds.createCounterSale(
        clubId: 1,
        tipoPago: 'EFECTIVO',
        tipoConsumo: 'EN_LUGAR',
        items: const [
          {
            'productoId': 1,
            'cantidad': 2,
            'nota': '',
            'opciones': [
              {'grupoId': 3, 'opcionId': 6, 'cantidad': 1},
            ],
          },
        ],
      );

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'POST');
      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['tipoPago'], 'EFECTIVO');
      expect(body['items'], isNotEmpty);
      final item = (body['items'] as List).first as Map<String, dynamic>;
      expect(item['opciones'], hasLength(1));
      expect(item.containsKey('comboId'), isFalse);
    }));

    test('sendOrder sin membresiaId lanza sin llamar a la red', async_(() async {
      final order = OrderEntity(
        id: 'o1',
        userId: 'u1',
        clubId: 1,
        membresiaId: null,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
      );

      await expectLater(
        () => ds.sendOrder(order, items: const [], combos: const []),
        throwsException,
      );
      expect(adapter.requests, isEmpty);
    }));

    test('sendOrder sin items lanza sin llamar a la red', async_(() async {
      final order = OrderEntity(
        id: 'o1',
        userId: 'u1',
        clubId: 1,
        membresiaId: 5,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
      );

      await expectLater(
        () => ds.sendOrder(order, items: const [], combos: const []),
        throwsException,
      );
      expect(adapter.requests, isEmpty);
    }));

    test('sendOrder válido hace POST a /pedidos/con-items', async_(() async {
      adapter.stub('POST', '/pedidos/con-items', statusCode: 201, data: {});
      final order = OrderEntity(
        id: 'o1',
        userId: 'u1',
        clubId: 1,
        membresiaId: 5,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
      );
      final items = [OrderItem(orderId: 'o1', productId: '1', quantity: 2)];

      await ds.sendOrder(order, items: items, combos: const []);

      expect(adapter.requests, hasLength(1));
    }));

    test('sendOrder moderno envía combos[]', async_(() async {
      adapter.stub('POST', '/pedidos/con-items', statusCode: 200, data: {});
      final order = OrderEntity(
        id: 'o1',
        userId: 'u1',
        clubId: 1,
        membresiaId: 5,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
        combos: [
          OrderCombo(
            orderId: 'o1',
            comboId: 4,
            comboName: 'Combo',
            quantity: 2,
            priceSnapshot: 38,
            pointsSnapshot: 15,
            components: [
              OrderComboComponent(productId: 7, productName: 'Batido'),
            ],
          ),
        ],
      );

      await ds.sendOrder(order, items: const [], combos: order.combos);

      final sentBody = adapter.requests.single.data as Map;
      final sentCombos = sentBody['combos'] as List;
      expect(sentCombos, hasLength(1));
      expect(sentCombos.single['comboId'], 4);
      expect(sentCombos.single['cantidad'], 2);
      expect(sentCombos.single.containsKey('precio'), isFalse);
    }));

    test('sendOrder con 401 lanza AppException', async_(() async {
      adapter.stub('POST', '/pedidos/con-items', statusCode: 401, data: {});
      final order = OrderEntity(
        id: 'o1',
        userId: 'u1',
        clubId: 1,
        membresiaId: 5,
        status: 'pending',
        createdAt: DateTime(2024, 1, 1),
      );
      final items = [OrderItem(orderId: 'o1', productId: '1', quantity: 1)];

      await expectLater(
        () => ds.sendOrder(order, items: items, combos: const []),
        throwsA(isA<AppException>()),
      );
    }));

    test('createCounterSale con error del servidor se mapea',
        async_(() async {
      adapter.stub('POST', '/pedidos/mostrador', statusCode: 500, data: {});

      await expectLater(
        () => ds.createCounterSale(
          clubId: 1,
          tipoPago: 'EFECTIVO',
          items: const [
            {'productoId': 1, 'cantidad': 1, 'nota': '', 'opciones': []},
          ],
        ),
        throwsA(isA<AppException>()),
      );
    }));

    test('getOrdersByClub con 401 lanza AppException', async_(() async {
      adapter.stub('GET', '/pedidos/club/5', statusCode: 401, data: {});
      await expectLater(
        () => ds.getOrdersByClub(5),
        throwsA(isA<AppException>()),
      );
    }));

    test('getOrdersByClub con 403 lanza AppException', async_(() async {
      adapter.stub('GET', '/pedidos/club/5', statusCode: 403, data: {});
      await expectLater(
        () => ds.getOrdersByClub(5),
        throwsA(isA<AppException>()),
      );
    }));

    test('getOrdersByClub con 500 lanza AppException', async_(() async {
      adapter.stub('GET', '/pedidos/club/5', statusCode: 500, data: {});
      await expectLater(
        () => ds.getOrdersByClub(5),
        throwsA(isA<AppException>()),
      );
    }));

    test('getOrdersBySocio soporta respuesta envuelta en "data"',
        async_(() async {
      adapter.stub('GET', '/pedidos/socio/7', data: {
        'data': [
          {'id': 20, 'membresiaId': 7},
        ],
      });
      final orders = await ds.getOrdersBySocio(7);
      expect(orders, hasLength(1));
    }));

    test('getOrdersBySocio con 401 lanza AppException', async_(() async {
      adapter.stub('GET', '/pedidos/socio/7', statusCode: 401, data: {});
      await expectLater(
        () => ds.getOrdersBySocio(7),
        throwsA(isA<AppException>()),
      );
    }));

    test('getOrdersBySocio con 403 lanza AppException', async_(() async {
      adapter.stub('GET', '/pedidos/socio/7', statusCode: 403, data: {});
      await expectLater(
        () => ds.getOrdersBySocio(7),
        throwsA(isA<AppException>()),
      );
    }));

    test('getOrdersByClubPage con error se mapea', async_(() async {
      adapter.stub('GET', '/pedidos/club/5/paginados', statusCode: 500, data: {});
      await expectLater(
        () => ds.getOrdersByClubPage(5),
        throwsA(isA<AppException>()),
      );
    }));

    test('getOrdersByClubPage con respuesta no Map lanza excepción',
        async_(() async {
      adapter.stub('GET', '/pedidos/club/5/paginados', data: [1, 2]);
      await expectLater(
        () => ds.getOrdersByClubPage(5),
        throwsA(isA<AppException>()),
      );
    }));

    test('getOrdersBySocioPage parsea PagedResult con filtros', async_(() async {
      adapter.stub('GET', '/pedidos/socio/7/paginados', data: {
        'content': [
          {'id': 1, 'membresiaId': 7},
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

      final page = await ds.getOrdersBySocioPage(
        7,
        estado: 'PENDIENTE',
        desde: '2024-01-01',
        hasta: '2024-01-31',
      );

      expect(page.content, hasLength(1));
      final sentUri = adapter.requests.last.uri;
      expect(sentUri.queryParameters['estado'], 'PENDIENTE');
    }));

    test('getOrdersBySocioPage con respuesta no Map lanza excepción',
        async_(() async {
      adapter.stub('GET', '/pedidos/socio/7/paginados', data: 'no-map');
      await expectLater(
        () => ds.getOrdersBySocioPage(7),
        throwsA(isA<AppException>()),
      );
    }));

    test('getAllOrders parsea lista completa', async_(() async {
      adapter.stub('GET', '/pedidos', data: [
        {'id': 1, 'clubId': 1},
        {'id': 2, 'clubId': 2},
      ]);
      final orders = await ds.getAllOrders();
      expect(orders, hasLength(2));
    }));

    test('getAllOrders soporta envoltorio content', async_(() async {
      adapter.stub('GET', '/pedidos', data: {
        'content': [
          {'id': 1},
        ],
      });
      final orders = await ds.getAllOrders();
      expect(orders, hasLength(1));
    }));

    test('getAllOrders con error se mapea', async_(() async {
      adapter.stub('GET', '/pedidos', statusCode: 500, data: {});
      await expectLater(() => ds.getAllOrders(), throwsA(isA<AppException>()));
    }));

    test('updateOrderStatus con tiempoEstimado envía query y body',
        async_(() async {
      adapter.stub('PATCH', '/pedidos/10/estado', statusCode: 204, data: {});

      await ds.updateOrderStatus(10, 'LISTO', estimatedTime: 20);

      final sent = adapter.requests.single;
      expect(sent.queryParameters['tiempoEstimadoMinutos'], 20);
      expect((sent.data as Map)['tiempoEstimadoMinutos'], 20);
    }));

    test('updateOrderStatus con 401 lanza AppException', async_(() async {
      adapter.stub('PATCH', '/pedidos/10/estado', statusCode: 401, data: {});
      await expectLater(
        () => ds.updateOrderStatus(10, 'LISTO'),
        throwsA(isA<AppException>()),
      );
    }));

    test('updateOrderStatus con 403 lanza AppException', async_(() async {
      adapter.stub('PATCH', '/pedidos/10/estado', statusCode: 403, data: {});
      await expectLater(
        () => ds.updateOrderStatus(10, 'LISTO'),
        throwsA(isA<AppException>()),
      );
    }));

    test('updateOrderStatus con 500 lanza AppException', async_(() async {
      adapter.stub('PATCH', '/pedidos/10/estado', statusCode: 500, data: {});
      await expectLater(
        () => ds.updateOrderStatus(10, 'LISTO'),
        throwsA(isA<AppException>()),
      );
    }));
  });

  group('AuthRemoteDataSourceImpl', () {
    late _FakeAdapter adapter;
    late AuthRemoteDataSourceImpl ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = AuthRemoteDataSourceImpl(_buildDio(adapter));
    });

    test('login con ADMIN lanza ADMIN_MOBILE_NOT_SUPPORTED', async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'jwt-123',
        'usuario': {
          'id': 1,
          'nombre': 'Ana',
          'apellido': 'Gomez',
          'email': 'ana@test.com',
          'rolNombre': 'ADMIN',
        },
      });

      await expectLater(
        () => ds.login('ana@test.com', 'secret123'),
        throwsA(isA<AdminMobileNotSupportedException>()),
      );
    }));

    test('login parsea rol ANFITRION como host', async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'jwt-123',
        'usuario': {
          'id': 1,
          'nombre': 'Ana',
          'apellido': 'Gomez',
          'email': 'ana@test.com',
          'rolNombre': 'ANFITRION',
        },
      });

      final user = await ds.login('ana@test.com', 'secret123');

      expect(user.id, '1');
      expect(user.name, 'Ana Gomez');
      expect(user.token, 'jwt-123');
      expect(user.role, 'host');
    }));

    test('login parsea rol basic_user por nombre', async_(() async {
      adapter.stub('POST', '/auth/login', data: {
        'token': 'jwt-456',
        'usuario': {
          'id': 2,
          'nombre': 'Beto',
          'apellido': 'Lopez',
          'email': 'beto@test.com',
          'rolNombre': 'USUARIO_BASICO',
        },
      });

      final user = await ds.login('beto@test.com', 'secret123');

      expect(user.role, 'basic_user');
    }));

    test('getMe parsea rol por objeto anidado (ignora id)', async_(() async {
      adapter.stub('GET', '/auth/me', data: {
        'id': 3,
        'nombre': 'Carla',
        'apellido': 'Diaz',
        'email': 'carla@test.com',
        'rol': {'id': 99, 'nombre': 'SOCIO'},
        'token': 'jwt-789',
      });

      final user = await ds.getMe();

      expect(user.id, '3');
      expect(user.name, 'Carla Diaz');
      expect(user.role, 'member');
    }));
  });

  group('MembresiaRemoteDataSourceImpl', () {
    late _FakeAdapter adapter;
    late MembresiaRemoteDataSourceImpl ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = MembresiaRemoteDataSourceImpl(_buildDio(adapter));
    });

    test('buscarMiembrosGlobal parsea lista de membresías', async_(() async {
      adapter.stub('GET', '/membresias/buscar', data: [
        {
          'id': 1,
          'usuarioId': 10,
          'usuarioNombre': 'Ana',
          'clubId': 2,
          'clubNombre': 'Club Norte',
          'numeroSocio': 'S-001',
        },
      ]);

      final result = await ds.buscarMiembrosGlobal(query: 'ana');

      expect(result, hasLength(1));
      expect(result.first.numeroSocio, 'S-001');
    }));

    test('buscarMiembrosGlobalPage parsea PagedResult<ClubMembership>',
        async_(() async {
      adapter.stub('GET', '/membresias/buscar/paginado', data: {
        'content': [
          {
            'id': 1,
            'usuarioId': 10,
            'clubId': 2,
            'numeroSocio': 'S-001',
          },
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

      final page = await ds.buscarMiembrosGlobalPage(query: 'a');

      expect(page.content, hasLength(1));
      expect(page.content.single.numeroSocio, 'S-001');
    }));
  });

  group('SupportRemoteDataSourceImpl', () {
    late _FakeAdapter adapter;
    late SupportRemoteDataSourceImpl ds;

    setUp(() {
      adapter = _FakeAdapter();
      ds = SupportRemoteDataSourceImpl(_buildDio(adapter));
    });

    test('getTicketsByUser parsea lista de tickets', async_(() async {
      adapter.stub('GET', '/soporte-tickets/usuario/7', data: [
        {
          'id': 1,
          'usuarioId': 7,
          'asunto': 'Problema con pedido',
          'mensaje': 'Detalle',
          'estado': 'abierto',
        },
      ]);

      final tickets = await ds.getTicketsByUser(7);

      expect(tickets, hasLength(1));
      expect(tickets.first.estado, 'ABIERTO');
    }));

    test('createTicket exitoso no lanza excepción', async_(() async {
      adapter.stub('POST', '/soporte-tickets', statusCode: 201, data: {});

      await ds.createTicket(
        tipoSolicitud: 'Queja',
        asunto: 'Asunto',
        mensaje: 'Mensaje',
      );

      expect(adapter.requests, hasLength(1));
    }));

    test('createTicket con error del servidor lanza excepción', async_(() async {
      adapter.stub('POST', '/soporte-tickets', statusCode: 500, data: {
        'message': 'Error interno',
      });

      await expectLater(
        () => ds.createTicket(
          tipoSolicitud: 'Queja',
          asunto: 'Asunto',
          mensaje: 'Mensaje',
        ),
        throwsException,
      );
    }));
  });
}

/// Helper para pasar closures async como segundo argumento de [test].
dynamic async_(Future<void> Function() body) => body;
