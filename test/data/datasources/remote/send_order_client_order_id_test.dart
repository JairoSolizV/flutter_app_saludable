import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_test/flutter_test.dart';

const kTestClientOrderId = '550e8400-e29b-41d4-a716-446655440000';
const kTestClientOrderIdUpper = '550E8400-E29B-41D4-A716-446655440000';

class _FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      201,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

OrderEntity _baseOrder({String id = kTestClientOrderId}) => OrderEntity(
      id: id,
      userId: 'u1',
      clubId: 1,
      membresiaId: 5,
      status: 'pending',
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  late _FakeAdapter adapter;
  late OrderRemoteDataSourceImpl ds;

  setUp(() {
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.httpClientAdapter = adapter;
    ds = OrderRemoteDataSourceImpl(dio);
  });

  test('sendOrder incluye clientOrderId = order.id', () async {
    final order = _baseOrder();
    final items = [
      OrderItem(orderId: kTestClientOrderId, productId: '1', quantity: 2),
    ];

    await ds.sendOrder(order, items: items, combos: const []);

    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect(body['clientOrderId'], kTestClientOrderId);
  });

  test('dos sendOrder con el mismo OrderEntity envían el mismo clientOrderId',
      () async {
    final order = _baseOrder();
    final items = [
      OrderItem(orderId: kTestClientOrderId, productId: '1', quantity: 1),
    ];

    await ds.sendOrder(order, items: items, combos: const []);
    await ds.sendOrder(order, items: items, combos: const []);

    expect(adapter.requests, hasLength(2));
    final first = (adapter.requests[0].data as Map)['clientOrderId'];
    final second = (adapter.requests[1].data as Map)['clientOrderId'];
    expect(first, kTestClientOrderId);
    expect(second, kTestClientOrderId);
    expect(first, second);
  });

  test('pedido solo items incluye clientOrderId', () async {
    final order = _baseOrder();
    await ds.sendOrder(
      order,
      items: [
        OrderItem(orderId: kTestClientOrderId, productId: '7', quantity: 1),
      ],
      combos: const [],
    );

    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect(body['clientOrderId'], kTestClientOrderId);
    expect(body['items'], hasLength(1));
    expect(body.containsKey('combos'), isFalse);
  });

  test('pedido con combo moderno y opciones incluye clientOrderId sin regresión',
      () async {
    final order = _baseOrder();
    final combos = [
      OrderCombo(
        orderId: kTestClientOrderId,
        comboId: 4,
        comboName: 'Combo',
        quantity: 2,
        priceSnapshot: 38,
        pointsSnapshot: 15,
        components: [
          OrderComboComponent(
            productId: 7,
            productName: 'Batido',
            options: const [
              OrderItemOption(groupId: 3, optionId: 6, quantity: 1),
            ],
          ),
        ],
      ),
    ];

    await ds.sendOrder(order, items: const [], combos: combos);

    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect(body['clientOrderId'], kTestClientOrderId);
    final sentCombos = body['combos'] as List;
    expect(sentCombos, hasLength(1));
    expect(sentCombos.single['comboId'], 4);
    final componentes = sentCombos.single['componentes'] as List;
    expect(componentes.single['opciones'], isNotEmpty);
  });

  test('acepta UUID en mayúsculas sin transformar el valor enviado', () async {
    final order = _baseOrder(id: kTestClientOrderIdUpper);
    await ds.sendOrder(
      order,
      items: [
        OrderItem(
          orderId: kTestClientOrderIdUpper,
          productId: '1',
          quantity: 1,
        ),
      ],
      combos: const [],
    );

    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect(body['clientOrderId'], kTestClientOrderIdUpper);
  });

  test('id vacío lanza ValidationException sin llamar a la red', () async {
    final order = _baseOrder(id: '   ');
    await expectLater(
      () => ds.sendOrder(
        order,
        items: [
          OrderItem(orderId: '   ', productId: '1', quantity: 1),
        ],
        combos: const [],
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('id no UUID lanza ValidationException sin llamar a la red', () async {
    final order = _baseOrder(id: 'order-1');
    await expectLater(
      () => ds.sendOrder(
        order,
        items: [
          OrderItem(orderId: 'order-1', productId: '1', quantity: 1),
        ],
        combos: const [],
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(adapter.requests, isEmpty);
  });
}
