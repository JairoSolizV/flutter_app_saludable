import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/combo_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/domain/entities/combo.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/presentation/providers/counter_sale_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProductRemoteDataSource implements ProductRemoteDataSource {
  List<Product> products = [];
  Object? loadError;
  int getProductsCalls = 0;

  @override
  Future<List<Product>> getProducts({
    required int hubId,
    required int clubId,
  }) async {
    getProductsCalls++;
    if (loadError != null) throw loadError!;
    return products;
  }

  @override
  Future<List<Product>> getAvailableProductsByClub(int clubId) async =>
      throw UnimplementedError();

  @override
  Future<void> createProduct(Product product, int clubId) async =>
      throw UnimplementedError();

  @override
  Future<String> uploadProductImage(File imageFile) async =>
      throw UnimplementedError();

  @override
  Future<void> createProductProposal({
    required int hubId,
    required String nombre,
    required String descripcion,
    required String ingredientes,
    required int puntosValor,
    String? imagenUrl,
    List<ProductOptionGroup>? optionGroups,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Product> updateProduct(Product product) async =>
      throw UnimplementedError();

  @override
  Future<Product> reenviarProducto(String productId) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteProduct(String id) async => throw UnimplementedError();

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async =>
      throw UnimplementedError();
}

class _FakeOrderRemoteDataSource implements OrderRemoteDataSource {
  bool shouldFail = false;
  int createCounterSaleCalls = 0;
  List<Map<String, dynamic>>? lastItems;

  @override
  Future<void> createCounterSale({
    required int clubId,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
  }) async {
    createCounterSaleCalls++;
    lastItems = items;
    if (shouldFail) {
      throw ServerException('No se pudo registrar la venta');
    }
  }

  @override
  Future<void> sendOrder(OrderEntity order, List<OrderItem> items) async =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId) async =>
      [];

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(
    int clubId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) async =>
      PagedResult<Map<String, dynamic>>.empty(page: page, size: size);

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(
    int membresiaId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) async =>
      PagedResult<Map<String, dynamic>>.empty(page: page, size: size);

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus,
          {int? estimatedTime}) async =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() async =>
      throw UnimplementedError();
}

/// Adapter Dio configurable para simular respuestas de ComboRemoteDataSource.
class _FakeComboAdapter implements HttpClientAdapter {
  int statusCode = 200;
  String body = '[]';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Product _product({
  required String id,
  required String name,
  int puntos = 1,
  String tipo = 'GLOBAL',
}) {
  return Product(
    id: id,
    name: name,
    description: '',
    puntosValor: puntos,
    tipo: tipo,
    active: true,
    available: true,
  );
}

void main() {
  group('CounterSaleProvider', () {
    late _FakeProductRemoteDataSource productDs;
    late _FakeOrderRemoteDataSource orderDs;
    late _FakeComboAdapter comboAdapter;
    late ComboRemoteDataSource comboDs;
    late CounterSaleProvider provider;

    final p1 = _product(id: '1', name: 'Batido', puntos: 10, tipo: 'GLOBAL');
    final p2 = _product(id: '2', name: 'Te', puntos: 5, tipo: 'LOCAL');
    final p3 = _product(id: '3', name: 'Aloe', puntos: 8, tipo: 'GLOBAL');
    final p4 = _product(id: '4', name: 'Extra', puntos: 3, tipo: 'GLOBAL');

    setUp(() {
      productDs = _FakeProductRemoteDataSource()
        ..products = [p1, p2, p3, p4];
      orderDs = _FakeOrderRemoteDataSource();
      comboAdapter = _FakeComboAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.httpClientAdapter = comboAdapter;
      comboDs = ComboRemoteDataSource(dio);
      provider = CounterSaleProvider(productDs, orderDs, comboDs);
    });

    test('init/loadCatalog separa productos globales y locales', () async {
      await provider.init(clubId: 1, hubId: 10);

      expect(provider.clubId, 1);
      expect(provider.hubId, 10);
      expect(provider.isCatalogLoading, isFalse);
      expect(provider.catalogError, isNull);
      expect(provider.generalProducts.map((p) => p.id), ['1', '3', '4']);
      expect(provider.clubSpecialties.map((p) => p.id), ['2']);
    });

    test('loadCatalog con fallo del datasource de productos setea catalogError',
        () async {
      productDs.loadError = ServerException('Error de catálogo');
      provider.clubId = 1;
      provider.hubId = 1;

      await provider.loadCatalog();

      expect(provider.catalogError, isNotNull);
      expect(provider.isCatalogLoading, isFalse);
    });

    test('fallo al cargar combos no afecta catalogError y deja combos vacíos',
        () async {
      comboAdapter.statusCode = 500;
      comboAdapter.body = '{"message":"boom"}';

      await provider.init(clubId: 1, hubId: 1);

      expect(provider.activeCombos, isEmpty);
      expect(provider.catalogError, isNull);
    });

    test('loadCatalog carga combos activos correctamente', () async {
      comboAdapter.body = '''
      [
        {"id": 9, "clubId": 1, "nombre": "Combo Feliz", "activo": true, "items": []},
        {"id": 10, "clubId": 1, "nombre": "Combo Inactivo", "activo": false, "items": []}
      ]
      ''';

      await provider.init(clubId: 1, hubId: 1);

      expect(provider.activeCombos, hasLength(1));
      expect(provider.activeCombos.first.nombre, 'Combo Feliz');
    });

    test('addProduct respeta el máximo de 3 sabores distintos', () async {
      await provider.init(clubId: 1, hubId: 1);

      expect(provider.addProduct(p1), isTrue);
      expect(provider.addProduct(p2), isTrue);
      expect(provider.addProduct(p3), isTrue);
      expect(provider.distinctProducts, 3);
      expect(provider.isMaxSaboresReached, isTrue);

      expect(provider.addProduct(p4), isFalse);
      expect(provider.distinctProducts, 3);
    });

    test('addProduct existente incrementa cantidad en vez de agregar nuevo',
        () async {
      await provider.init(clubId: 1, hubId: 1);

      provider.addProduct(p1);
      provider.addProduct(p1);

      expect(provider.distinctProducts, 1);
      expect(provider.cartItems.single.quantity, 2);
    });

    test('addCombo agrega todos los items expandidos con referencia al combo',
        () async {
      await provider.init(clubId: 1, hubId: 1);
      final combo = Combo(
        id: 5,
        clubId: 1,
        nombre: 'Combo Doble',
        items: [
          ComboItem(productoId: 1, productoNombre: 'Batido', cantidad: 2),
          ComboItem(productoId: 3, productoNombre: 'Aloe', cantidad: 1),
        ],
      );

      final ok = provider.addCombo(combo);

      expect(ok, isTrue);
      expect(provider.distinctProducts, 2);
      final batidoItem = provider.cartItems.firstWhere((i) => i.product.id == '1');
      expect(batidoItem.quantity, 2);
      expect(batidoItem.comboId, 5);
      expect(batidoItem.comboNombre, 'Combo Doble');
    });

    test('addCombo retorna false si excede el máximo de sabores',
        () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProduct(p4);

      final combo = Combo(
        id: 6,
        clubId: 1,
        nombre: 'Combo Grande',
        items: [
          ComboItem(productoId: 1, productoNombre: 'Batido'),
          ComboItem(productoId: 2, productoNombre: 'Te'),
          ComboItem(productoId: 3, productoNombre: 'Aloe'),
        ],
      );

      final ok = provider.addCombo(combo);

      expect(ok, isFalse);
      expect(provider.distinctProducts, 1);
    });

    test('increaseQty/decreaseQty modifican cantidad y remueven al llegar a 0',
        () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProduct(p1);

      provider.increaseQty('1');
      expect(provider.cartItems.single.quantity, 2);

      provider.decreaseQty('1');
      expect(provider.cartItems.single.quantity, 1);

      provider.decreaseQty('1');
      expect(provider.cartItems, isEmpty);
    });

    test('removeItem elimina el producto del carrito', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProduct(p1);
      provider.addProduct(p2);

      provider.removeItem('1');

      expect(provider.cartItems.map((i) => i.product.id), ['2']);
    });

    test('canSubmit es false con carrito vacío y true con items', () async {
      await provider.init(clubId: 1, hubId: 1);
      expect(provider.canSubmit, isFalse);

      provider.addProduct(p1);
      expect(provider.canSubmit, isTrue);
    });

    test('totalPuntos suma puntosValor * cantidad de cada item', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProduct(p1); // 10 pts
      provider.increaseQty('1'); // qty 2 -> 20 pts
      provider.addProduct(p3); // 8 pts

      expect(provider.totalPuntos, 28);
    });

    test('submitCounterSale exitoso marca submitSuccess y limpia submitError',
        () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProduct(p1);

      final ok = await provider.submitCounterSale();

      expect(ok, isTrue);
      expect(provider.submitSuccess, isTrue);
      expect(provider.submitError, isNull);
      expect(provider.isSubmitting, isFalse);
      expect(orderDs.createCounterSaleCalls, 1);
    });

    test('submitCounterSale fallido setea submitError y submitSuccess false',
        () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProduct(p1);
      orderDs.shouldFail = true;

      final ok = await provider.submitCounterSale();

      expect(ok, isFalse);
      expect(provider.submitSuccess, isFalse);
      expect(provider.submitError, isNotNull);
      expect(provider.isSubmitting, isFalse);
    });

    test('submitCounterSale sin productos en el carrito falla sin llamar al datasource',
        () async {
      provider.clubId = 1;

      final ok = await provider.submitCounterSale();

      expect(ok, isFalse);
      expect(provider.submitError, isNotNull);
      expect(orderDs.createCounterSaleCalls, 0);
    });

    test('doble submit concurrente: la segunda llamada retorna false de inmediato',
        () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProduct(p1);

      final first = provider.submitCounterSale();
      final second = provider.submitCounterSale();

      final secondResult = await second;
      final firstResult = await first;

      expect(secondResult, isFalse);
      expect(firstResult, isTrue);
      expect(orderDs.createCounterSaleCalls, 1);
    });

    test('resetSale limpia carrito y estado de envío sin borrar catálogo',
        () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProduct(p1);
      provider.setSocioCodigo('S-1');
      provider.setObservaciones('nota');
      await provider.submitCounterSale();

      provider.resetSale();

      expect(provider.cartItems, isEmpty);
      expect(provider.socioCodigo, '');
      expect(provider.observaciones, '');
      expect(provider.submitError, isNull);
      expect(provider.submitSuccess, isFalse);
      expect(provider.generalProducts, isNotEmpty);
    });

    test('clearSessionState limpia todo incluyendo catálogo', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProduct(p1);

      await provider.clearSessionState();

      expect(provider.clubId, isNull);
      expect(provider.hubId, isNull);
      expect(provider.cartItems, isEmpty);
      expect(provider.generalProducts, isEmpty);
      expect(provider.clubSpecialties, isEmpty);
      expect(provider.activeCombos, isEmpty);
    });
  });
}

