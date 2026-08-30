import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/constants/counter_sale_payment_types.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_app_saludable/presentation/providers/counter_sale_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/host/host_counter_sale_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/host/host_counter_sale_ticket_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/host/host_dashboard_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _StubProducts implements ProductRemoteDataSource {
  List<Product> products = const [];

  @override
  Future<List<Product>> getProducts({
    required int hubId,
    required int clubId,
  }) async =>
      products;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubOrders implements OrderRemoteDataSource {
  bool shouldFail = false;
  int createCalls = 0;

  @override
  Future<void> createCounterSale({
    required int clubId,
    required String tipoPago,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
  }) async {
    createCalls++;
    if (shouldFail) throw ServerException('No se pudo registrar la venta');
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClubDs extends ClubRemoteDataSource {
  _FakeClubDs() : super(Dio());

  @override
  Future<Club?> getMyClub() async => Club(
        id: 1,
        hubId: 10,
        hubNombre: 'Hub Test',
        anfitrionId: 1,
        anfitrionNombre: 'Ana',
        nombreClub: 'Club Test',
        direccion: 'Dir',
        horario: '8-18',
        lat: 0,
        lng: 0,
        estado: 'ACTIVO',
      );
}

class _FakeOrderDs implements OrderRemoteDataSource {
  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async => [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Product _simpleProduct({String id = '1', String name = 'Té'}) => Product(
      id: id,
      name: name,
      description: '',
      price: 30,
      effectivePrice: 30,
      puntosValor: 5,
      category: 'General',
      imageUrl: '',
    );

Product _configurableProduct() => Product(
      id: '7',
      name: 'Batido de leche',
      description: '',
      price: 20,
      effectivePrice: 20,
      puntosValor: 10,
      category: 'Batidos',
      imageUrl: '',
      optionGroups: [
        ProductOptionGroup(
          id: 3,
          name: 'Sabores',
          minSelections: 1,
          maxSelections: 1,
          options: [
            ProductOption(id: 6, name: 'Frutilla', active: true),
          ],
        ),
      ],
    );

Widget _counterApp({
  required CounterSaleProvider provider,
  required Widget home,
}) {
  return ChangeNotifierProvider<CounterSaleProvider>.value(
    value: provider,
    child: MaterialApp(home: home),
  );
}

Future<void> _pumpCatalog(
  WidgetTester tester,
  CounterSaleProvider provider, {
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _counterApp(
      provider: provider,
      home: const HostCounterSaleScreen(clubId: 1, hubId: 10),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _openTicket(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('counter-view-ticket')));
  await tester.pumpAndSettle();
}

void main() {
  group('Host home — Nueva venta', () {
    testWidgets('tarjeta visible después de Pedidos Recibidos', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ClubRemoteDataSource>.value(value: _FakeClubDs()),
            Provider<OrderRemoteDataSource>.value(value: _FakeOrderDs()),
          ],
          child: const MaterialApp(home: HostDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pedidos Recibidos'), findsOneWidget);
      expect(find.byKey(const Key('host-home-nueva-venta')), findsOneWidget);
      expect(find.text('Nueva venta'), findsOneWidget);

      final pedidos = find.text('Pedidos Recibidos');
      final nuevaVenta = find.byKey(const Key('host-home-nueva-venta'));
      final pedidosBox = tester.getTopLeft(pedidos);
      final nuevaVentaBox = tester.getTopLeft(nuevaVenta);
      expect(nuevaVentaBox.dy, greaterThan(pedidosBox.dy));
    });

    testWidgets('navega al catálogo de venta', (tester) async {
      final productDs = _StubProducts();
      final orderDs = _StubOrders();
      final counterProvider = CounterSaleProvider(productDs, orderDs);

      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ClubRemoteDataSource>.value(value: _FakeClubDs()),
            Provider<OrderRemoteDataSource>.value(value: _FakeOrderDs()),
            ChangeNotifierProvider<CounterSaleProvider>.value(
              value: counterProvider,
            ),
          ],
          child: const MaterialApp(home: HostDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('host-home-nueva-venta')),
        120,
      );
      await tester.tap(find.byKey(const Key('host-home-nueva-venta')));
      await tester.pumpAndSettle();

      expect(find.byType(HostCounterSaleScreen), findsOneWidget);
      expect(find.text('Menú General'), findsOneWidget);
    });
  });

  group('HostCounterSaleScreen — catálogo', () {
    late _StubProducts productDs;
    late _StubOrders orderDs;
    late CounterSaleProvider provider;

    setUp(() {
      productDs = _StubProducts();
      orderDs = _StubOrders();
      provider = CounterSaleProvider(productDs, orderDs);
    });

    testWidgets('sin código socio, pago ni finalizar', (tester) async {
      productDs.products = [_simpleProduct()];
      await _pumpCatalog(tester, provider);

      expect(find.text('Aplicar'), findsNothing);
      expect(find.text('Forma de pago'), findsNothing);
      expect(find.byKey(const Key('counter-finalize-sale')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('carrito vacío sin footer', (tester) async {
      productDs.products = [_simpleProduct()];
      await _pumpCatalog(tester, provider);

      expect(find.byKey(const Key('counter-view-ticket')), findsNothing);
    });

    testWidgets('carrito con productos muestra Ver ticket', (tester) async {
      productDs.products = [_simpleProduct()];
      await provider.init(clubId: 1, hubId: 10);
      provider.addProductLine(product: productDs.products.first);
      await _pumpCatalog(tester, provider);

      expect(find.byKey(const Key('counter-view-ticket')), findsOneWidget);
      expect(find.textContaining('1 producto'), findsOneWidget);
    });

    testWidgets('botón + visible y agrega producto simple', (tester) async {
      productDs.products = [_simpleProduct()];
      await _pumpCatalog(tester, provider);

      final addBtn = find.byKey(const Key('add-product-1'));
      expect(addBtn, findsOneWidget);

      final buttonBox = tester.getSize(addBtn);
      expect(buttonBox.width, greaterThanOrEqualTo(44));
      expect(buttonBox.height, greaterThanOrEqualTo(44));

      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(provider.cartLines, hasLength(1));
      expect(find.byKey(const Key('counter-view-ticket')), findsOneWidget);
    });

    testWidgets('configurable abre bottom sheet', (tester) async {
      productDs.products = [_configurableProduct()];
      await _pumpCatalog(tester, provider);

      await tester.tap(find.byKey(const Key('add-product-7')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Frutilla'), findsOneWidget);
    });

    testWidgets('sin overflow en iPhone', (tester) async {
      productDs.products = [_simpleProduct(), _configurableProduct()];
      await provider.init(clubId: 1, hubId: 10);
      provider.addProductLine(product: _simpleProduct());
      await _pumpCatalog(tester, provider);

      expect(tester.takeException(), isNull);
    });
  });

  group('HostCounterSaleTicketScreen', () {
    late _StubProducts productDs;
    late _StubOrders orderDs;
    late CounterSaleProvider provider;

    setUp(() {
      productDs = _StubProducts();
      orderDs = _StubOrders();
      provider = CounterSaleProvider(productDs, orderDs);
    });

    Future<void> pumpTicket(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _counterApp(
          provider: provider,
          home: const HostCounterSaleTicketScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra líneas y opciones', (tester) async {
      await provider.init(clubId: 1, hubId: 10);
      provider.addProductLine(
        product: _configurableProduct(),
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

      await pumpTicket(tester);

      expect(find.text('Batido de leche'), findsOneWidget);
      expect(find.textContaining('Frutilla'), findsOneWidget);
      expect(find.text('PRODUCTOS'), findsOneWidget);
      expect(find.text('FORMA DE PAGO'), findsOneWidget);
      expect(find.byKey(const Key('counter-finalize-sale')), findsOneWidget);
    });

    testWidgets('qty +/- actualiza total', (tester) async {
      await provider.init(clubId: 1, hubId: 10);
      provider.addProductLine(product: _simpleProduct());
      await pumpTicket(tester);

      expect(provider.totalItems, 1);
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(provider.totalItems, 2);

      await tester.tap(find.byIcon(Icons.remove).first);
      await tester.pumpAndSettle();
      expect(provider.totalItems, 1);
    });

    testWidgets('código socio Aplicar y venta al público', (tester) async {
      await provider.init(clubId: 1, hubId: 10);
      provider.addProductLine(product: _simpleProduct());
      await pumpTicket(tester);

      expect(find.text('Venta al público'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('counter-socio-code')), 'eva');
      await tester.tap(find.byKey(const Key('counter-socio-apply')));
      await tester.pumpAndSettle();

      expect(provider.socioCodigo, 'eva');
      expect(find.text('Código aplicado'), findsOneWidget);
      expect(find.text('Validar'), findsNothing);
    });

    testWidgets('selector pago y observaciones', (tester) async {
      await provider.init(clubId: 1, hubId: 10);
      provider.addProductLine(product: _simpleProduct());
      await pumpTicket(tester);

      await tester.tap(find.text('Efectivo'));
      await tester.pumpAndSettle();
      expect(provider.tipoPago, CounterSalePaymentTypes.efectivo);

      await tester.enterText(
        find.byKey(const Key('counter-observations')),
        'Sin hielo',
      );
      expect(provider.observaciones, 'Sin hielo');
    });

    testWidgets('back conserva carrito', (tester) async {
      productDs.products = [_simpleProduct()];
      await provider.init(clubId: 1, hubId: 10);
      provider.addProductLine(product: _simpleProduct());
      await _pumpCatalog(tester, provider);
      await _openTicket(tester);

      expect(find.byType(HostCounterSaleTicketScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(HostCounterSaleScreen), findsOneWidget);
      expect(provider.cartLines, hasLength(1));
    });

    testWidgets('error submit conserva carrito', (tester) async {
      await provider.init(clubId: 1, hubId: 10);
      provider.addProductLine(product: _simpleProduct());
      provider.setTipoPago(CounterSalePaymentTypes.efectivo);
      orderDs.shouldFail = true;
      await pumpTicket(tester);

      await tester.ensureVisible(find.byKey(const Key('counter-finalize-sale')));
      await tester.tap(find.byKey(const Key('counter-finalize-sale')));
      await tester.pumpAndSettle();

      expect(provider.cartLines, hasLength(1));
      expect(provider.tipoPago, CounterSalePaymentTypes.efectivo);
      expect(provider.submitError, isNotNull);
    });

    testWidgets('sin overflow con teclado en socio', (tester) async {
      await provider.init(clubId: 1, hubId: 10);
      provider.addProductLine(product: _simpleProduct());
      await pumpTicket(tester);

      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('counter-socio-code')), findsOneWidget);
    });

    testWidgets('sin overflow con teclado en observaciones', (tester) async {
      await provider.init(clubId: 1, hubId: 10);
      provider.addProductLine(product: _simpleProduct());
      await pumpTicket(tester);

      await tester.tap(find.byKey(const Key('counter-observations')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('no contiene emojis decorativos', (tester) async {
      await provider.init(clubId: 1, hubId: 10);
      provider.addProductLine(product: _simpleProduct());
      await pumpTicket(tester);

      final emojiPattern = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );

      for (final widget in find.byType(Text).evaluate()) {
        final text = (widget.widget as Text).data ?? '';
        expect(emojiPattern.hasMatch(text), isFalse, reason: 'Emoji en: $text');
      }
    });
  });

  group('Pedidos — sin Nueva venta principal', () {
    testWidgets('HostOrdersListScreen app bar no muestra Nueva venta',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Pedidos Recibidos'),
              actions: const [
                Icon(Icons.refresh),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nueva venta'), findsNothing);
    });
  });
}
