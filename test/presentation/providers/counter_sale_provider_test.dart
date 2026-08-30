import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/constants/counter_sale_payment_types.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/combo_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/domain/entities/combo.dart';
import 'package:flutter_app_saludable/domain/entities/combo_cart_item.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
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
    required double precio,
    String? imagenUrl,
    List<ProductOptionGroup>? optionGroups,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Product> updateProduct(Product product) async =>
      throw UnimplementedError();

  @override
  Future<Product?> updateClubSalePrice({
    required int clubId,
    required String productId,
    required double? precioVenta,
  }) async =>
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
  List<Map<String, dynamic>>? lastCombos;
  String? lastTipoPago;

  @override
  Future<void> createCounterSale({
    required int clubId,
    required String tipoPago,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> combos = const [],
  }) async {
    createCounterSaleCalls++;
    lastItems = items;
    lastCombos = combos;
    lastTipoPago = tipoPago;
    if (shouldFail) {
      throw ServerException('No se pudo registrar la venta');
    }
  }

  @override
  Future<void> sendOrder(OrderEntity order,
          {required List<OrderItem> items, required List<OrderCombo> combos}) async =>
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

class _StubComboRemoteDataSource extends ComboRemoteDataSource {
  _StubComboRemoteDataSource() : super(Dio());

  List<Combo> combos = const [];

  @override
  Future<List<Combo>> getCombosByClub(int clubId) async => combos;
}

class _FakeComboAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '[]',
      200,
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
  double price = 20,
  List<ProductOptionGroup>? optionGroups,
}) {
  return Product(
    id: id,
    name: name,
    description: '',
    price: price,
    effectivePrice: price,
    puntosValor: puntos,
    tipo: tipo,
    active: true,
    available: true,
    optionGroups: optionGroups,
  );
}

Combo _combo({
  int id = 1,
  String name = 'Combo desayuno',
  double price = 35,
  int points = 15,
  bool activo = true,
  List<ComboItem>? items,
}) {
  return Combo(
    id: id,
    clubId: 1,
    nombre: name,
    price: price,
    puntosValor: points,
    activo: activo,
    items: items ??
        [
          ComboItem(productoId: 7, productoNombre: 'Batido de leche'),
          ComboItem(productoId: 2, productoNombre: 'Té Energético'),
        ],
  );
}

ComboCartItem _comboCartItem({
  int comboId = 1,
  int quantity = 1,
  List<ComboCartComponent>? components,
}) {
  return ComboCartItem(
    comboId: comboId,
    comboName: 'Combo desayuno',
    price: 35,
    points: 15,
    quantity: quantity,
    components: components ??
        const [
          ComboCartComponent(
            productId: 7,
            productName: 'Batido de leche',
            selections: [
              ProductOptionSelection(
                groupId: 3,
                groupName: 'Sabores',
                optionId: 6,
                optionName: 'Frutilla',
                quantity: 1,
              ),
            ],
          ),
          ComboCartComponent(
            productId: 2,
            productName: 'Té Energético',
          ),
        ],
  );
}

void main() {
  group('CounterSaleProvider', () {
    late _FakeProductRemoteDataSource productDs;
    late _FakeOrderRemoteDataSource orderDs;
    late CounterSaleProvider provider;

    late _StubComboRemoteDataSource comboDs;

    final pSimple = _product(id: '1', name: 'Té', puntos: 5, price: 30);
    final pConfigurable = _product(
      id: '7',
      name: 'Batido',
      puntos: 10,
      price: 20,
      optionGroups: [
        ProductOptionGroup(
          id: 3,
          name: 'Sabores',
          minSelections: 1,
          maxSelections: 1,
          options: [
            ProductOption(id: 6, name: 'Frutilla', active: true),
            ProductOption(id: 7, name: 'Cookies', active: true),
          ],
        ),
      ],
    );

    setUp(() {
      productDs = _FakeProductRemoteDataSource()
        ..products = [pSimple, pConfigurable];
      orderDs = _FakeOrderRemoteDataSource();
      comboDs = _StubComboRemoteDataSource();
      provider = CounterSaleProvider(
        productDs,
        orderDs,
        comboDs,
      );
    });

    test('init/loadCatalog separa productos globales y locales', () async {
      productDs.products = [
        pSimple,
        _product(id: '2', name: 'Local', tipo: 'LOCAL'),
      ];
      await provider.init(clubId: 1, hubId: 10);

      expect(provider.generalProducts, hasLength(1));
      expect(provider.clubSpecialties, hasLength(1));
    });

    test('addProductLine sin opciones agrega directo', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(product: pSimple);

      expect(provider.cartLines, hasLength(1));
      expect(provider.cartLines.single.quantity, 1);
      expect(provider.cartLines.single.selections, isEmpty);
    });

    test('configs distintas son líneas distintas', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(
        product: pConfigurable,
        selections: const [
          ProductOptionSelection(
            groupId: 3,
            groupName: 'Sabores',
            optionId: 6,
            optionName: 'Frutilla',
            quantity: 1,
          ),
        ],
      );
      provider.addProductLine(
        product: pConfigurable,
        selections: const [
          ProductOptionSelection(
            groupId: 3,
            groupName: 'Sabores',
            optionId: 7,
            optionName: 'Cookies',
            quantity: 1,
          ),
        ],
      );

      expect(provider.cartLines, hasLength(2));
    });

    test('misma config incrementa quantity', () async {
      await provider.init(clubId: 1, hubId: 1);
      const selections = [
        ProductOptionSelection(
          groupId: 3,
          groupName: 'Sabores',
          optionId: 6,
          optionName: 'Frutilla',
          quantity: 1,
        ),
      ];
      provider.addProductLine(
        product: pConfigurable,
        selections: selections,
      );
      provider.addProductLine(
        product: pConfigurable,
        selections: selections,
        quantity: 2,
      );

      expect(provider.cartLines, hasLength(1));
      expect(provider.cartLines.single.quantity, 3);
    });

    test('option quantity entra al configKey', () {
      const a = [
        ProductOptionSelection(
          groupId: 3,
          groupName: 'Sabores',
          optionId: 6,
          optionName: 'Frutilla',
          quantity: 1,
        ),
      ];
      const b = [
        ProductOptionSelection(
          groupId: 3,
          groupName: 'Sabores',
          optionId: 6,
          optionName: 'Frutilla',
          quantity: 2,
        ),
      ];
      expect(
        ProductOptionSelection.cartKey('7', a),
        isNot(equals(ProductOptionSelection.cartKey('7', b))),
      );
    });

    test('totalBs usa effectivePrice × quantity', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(product: pSimple, quantity: 2);

      expect(provider.totalBs, 60);
    });

    test('totalPuntos suma puntos × quantity', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(product: pSimple, quantity: 2);

      expect(provider.totalPuntos, 10);
    });

    test('canSubmit false sin tipoPago', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(product: pSimple);

      expect(provider.canSubmit, isFalse);
    });

    test('canSubmit true con tipoPago válido', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(product: pSimple);
      provider.setTipoPago(CounterSalePaymentTypes.efectivo);

      expect(provider.canSubmit, isTrue);
    });

    test('submitCounterSale manda opciones IDs y tipoPago', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(
        product: pConfigurable,
        selections: const [
          ProductOptionSelection(
            groupId: 3,
            groupName: 'Sabores',
            optionId: 6,
            optionName: 'Frutilla',
            quantity: 1,
          ),
        ],
      );
      provider.setTipoPago(CounterSalePaymentTypes.qr);

      final ok = await provider.submitCounterSale();

      expect(ok, isTrue);
      expect(orderDs.lastTipoPago, CounterSalePaymentTypes.qr);
      final item = orderDs.lastItems!.single;
      expect(item['opciones'], hasLength(1));
      expect(item['opciones'][0]['grupoId'], 3);
      expect(item['opciones'][0]['opcionId'], 6);
      expect(item.containsKey('comboId'), isFalse);
      expect(item['nota'], '');
    });

    test('submit sin tipoPago falla sin llamar datasource', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(product: pSimple);

      final ok = await provider.submitCounterSale();

      expect(ok, isFalse);
      expect(orderDs.createCounterSaleCalls, 0);
    });

    test('submit fallido conserva carrito', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(product: pSimple);
      provider.setTipoPago(CounterSalePaymentTypes.efectivo);
      orderDs.shouldFail = true;

      final ok = await provider.submitCounterSale();

      expect(ok, isFalse);
      expect(provider.cartLines, hasLength(1));
    });

    test('doble submit concurrente bloqueado', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(product: pSimple);
      provider.setTipoPago(CounterSalePaymentTypes.efectivo);

      final first = provider.submitCounterSale();
      final second = provider.submitCounterSale();

      expect(await second, isFalse);
      expect(await first, isTrue);
      expect(orderDs.createCounterSaleCalls, 1);
    });

    test('resetSale limpia carrito y tipoPago', () async {
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(product: pSimple);
      provider.setTipoPago(CounterSalePaymentTypes.efectivo);

      provider.resetSale();

      expect(provider.cartLines, isEmpty);
      expect(provider.comboCartLines, isEmpty);
      expect(provider.tipoPago, isNull);
    });

    test('combosEnabled es true con datasource de combos', () {
      expect(provider.combosEnabled, isTrue);
    });

    group('combos mostrador', () {
      test('addComboLine válido crea línea', () async {
        await provider.init(clubId: 1, hubId: 10);
        provider.addComboLine(_comboCartItem());

        expect(provider.comboCartLines, hasLength(1));
        expect(provider.comboCartLines.single.quantity, 1);
      });

      test('misma config incrementa quantity', () async {
        await provider.init(clubId: 1, hubId: 10);
        provider.addComboLine(_comboCartItem());
        provider.addComboLine(_comboCartItem(quantity: 2));

        expect(provider.comboCartLines, hasLength(1));
        expect(provider.comboCartLines.single.quantity, 3);
      });

      test('config distinta crea línea distinta', () async {
        await provider.init(clubId: 1, hubId: 10);
        provider.addComboLine(_comboCartItem());
        provider.addComboLine(
          _comboCartItem(
            components: const [
              ComboCartComponent(
                productId: 7,
                productName: 'Batido de leche',
                selections: [
                  ProductOptionSelection(
                    groupId: 3,
                    groupName: 'Sabores',
                    optionId: 7,
                    optionName: 'Cookies',
                    quantity: 1,
                  ),
                ],
              ),
              ComboCartComponent(
                productId: 2,
                productName: 'Té Energético',
              ),
            ],
          ),
        );

        expect(provider.comboCartLines, hasLength(2));
      });

      test('decreaseComboQty elimina en cero', () async {
        await provider.init(clubId: 1, hubId: 10);
        provider.addComboLine(_comboCartItem());
        provider.decreaseComboQty(provider.comboCartLines.single.configKey);

        expect(provider.comboCartLines, isEmpty);
      });

      test('totalBs mezcla producto y combo sin sumar componentes', () async {
        await provider.init(clubId: 1, hubId: 10);
        provider.addProductLine(product: pConfigurable, quantity: 1);
        provider.addComboLine(_comboCartItem(quantity: 2));

        expect(provider.totalBs, 90);
      });

      test('totalPuntos mezcla producto y combo una vez por combo', () async {
        await provider.init(clubId: 1, hubId: 10);
        provider.addProductLine(product: pSimple);
        provider.addComboLine(_comboCartItem(quantity: 2));

        expect(provider.totalPuntos, 35);
      });

      test('resetSale limpia comboCart', () async {
        await provider.init(clubId: 1, hubId: 10);
        provider.addComboLine(_comboCartItem());
        provider.resetSale();

        expect(provider.comboCartLines, isEmpty);
      });

      test('submit manda combos[] sin expandir en items', () async {
        await provider.init(clubId: 1, hubId: 10);
        provider.addProductLine(product: pSimple);
        provider.addComboLine(_comboCartItem(quantity: 2));
        provider.setTipoPago(CounterSalePaymentTypes.efectivo);

        final ok = await provider.submitCounterSale();

        expect(ok, isTrue);
        expect(orderDs.lastItems, hasLength(1));
        expect(orderDs.lastCombos, hasLength(1));
        final combo = orderDs.lastCombos!.single;
        expect(combo['comboId'], 1);
        expect(combo['cantidad'], 2);
        expect(combo.containsKey('precio'), isFalse);
        expect(combo.containsKey('puntos'), isFalse);
        final componentes = combo['componentes'] as List;
        expect(componentes, hasLength(2));
        expect(
          (componentes.first as Map).containsKey('productoNombre'),
          isFalse,
        );
        expect(orderDs.lastItems!.every((i) => i['comboId'] == null), isTrue);
      });

      test('canSubmit true solo con combo y tipoPago', () async {
        await provider.init(clubId: 1, hubId: 10);
        provider.addComboLine(_comboCartItem());
        provider.setTipoPago(CounterSalePaymentTypes.efectivo);

        expect(provider.canSubmit, isTrue);
      });
    });
  });
}
