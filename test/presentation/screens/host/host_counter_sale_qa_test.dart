import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/constants/counter_sale_payment_types.dart';
import 'package:flutter_app_saludable/core/utils/order_item_options_display.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/order_item_option.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/presentation/providers/counter_sale_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/host/host_counter_sale_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/host/host_counter_sale_ticket_screen.dart';
import 'package:flutter_app_saludable/presentation/widgets/order_history_lines.dart';
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

  @override
  Future<void> createCounterSale({
    required int clubId,
    required String tipoPago,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
  }) async {
    if (shouldFail) throw ServerException('No se pudo registrar la venta');
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _hostCounterApp(CounterSaleProvider provider, {Widget? home}) {
  return ChangeNotifierProvider<CounterSaleProvider>.value(
    value: provider,
    child: MaterialApp(
      home: home ?? const HostCounterSaleScreen(clubId: 1, hubId: 1),
    ),
  );
}

void main() {
  group('OrderItemOptionsDisplay.parseFromHistoryItem', () {
    test('acepta List<OrderItemOption> ya parseada', () {
      const options = [
        OrderItemOption(
          groupId: 3,
          groupName: 'Sabores',
          optionId: 6,
          optionName: 'frutilla',
          quantity: 1,
        ),
        OrderItemOption(
          groupId: 4,
          groupName: 'consistencia',
          optionId: 9,
          optionName: 'Cremoso',
          quantity: 1,
        ),
      ];

      final parsed = OrderItemOptionsDisplay.parseFromHistoryItem({
        'productoNombre': 'Batido de leche',
        'cantidad': 1,
        'opciones': options,
      });

      expect(parsed, hasLength(2));
      expect(
        OrderItemOptionsDisplay.hostBulletLines(parsed),
        [
          '- Sabores: frutilla',
          '- consistencia: Cremoso',
        ],
      );
    });

    test('producto sin opciones retorna vacío', () {
      final parsed = OrderItemOptionsDisplay.parseFromHistoryItem({
        'productoNombre': 'Té',
        'cantidad': 1,
        'opciones': const <OrderItemOption>[],
      });
      expect(parsed, isEmpty);
      expect(OrderItemOptionsDisplay.hostBulletLines(parsed), isEmpty);
    });
  });

  group('OrderHistoryLines host preparation', () {
    testWidgets('muestra opciones snapshot por línea', (tester) async {
      final order = {
        'items': [
          {
            'productoNombre': 'Batido de leche',
            'cantidad': 1,
            'opciones': [
              OrderItemOption(
                groupId: 3,
                groupName: 'Sabores',
                optionId: 6,
                optionName: 'frutilla',
                quantity: 1,
              ),
              OrderItemOption(
                groupId: 4,
                groupName: 'consistencia',
                optionId: 9,
                optionName: 'Cremoso',
                quantity: 1,
              ),
            ],
          },
          {
            'productoNombre': 'Batido de leche',
            'cantidad': 1,
            'opciones': [
              OrderItemOption(
                groupId: 3,
                groupName: 'Sabores',
                optionId: 6,
                optionName: 'frutilla',
                quantity: 1,
              ),
              OrderItemOption(
                groupId: 4,
                groupName: 'consistencia',
                optionId: 10,
                optionName: 'Líquido',
                quantity: 1,
              ),
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderHistoryLines(
              order: order,
              hostPreparationStyle: true,
            ),
          ),
        ),
      );

      expect(find.textContaining('Batido de leche'), findsNWidgets(2));
      expect(find.text('- Sabores: frutilla'), findsNWidgets(2));
      expect(find.text('- consistencia: Cremoso'), findsOneWidget);
      expect(find.text('- consistencia: Líquido'), findsOneWidget);
    });

    testWidgets('combo moderno sigue renderizando bloque combo', (tester) async {
      final order = {
        'combos': [
          {
            'pedidoComboId': 1,
            'comboNombre': 'Combo desayuno',
            'cantidad': 1,
            'subtotal': 38,
            'items': [
              {
                'productoNombre': 'Batido',
                'opciones': [
                  {
                    'grupoNombre': 'Sabores',
                    'opcionNombre': 'Frutilla',
                    'cantidad': 1,
                  },
                ],
              },
            ],
          },
        ],
        'items': [
          {
            'productoNombre': 'Batido',
            'cantidad': 1,
            'pedidoComboId': 1,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderHistoryLines(order: order, hostPreparationStyle: true),
          ),
        ),
      );

      expect(find.text('Combo desayuno ×1'), findsOneWidget);
      expect(find.textContaining('1 x Batido'), findsNothing);
    });
  });

  group('HostCounterSaleScreen layout', () {
    late _StubProducts productDs;
    late _StubOrders orderDs;
    late CounterSaleProvider provider;

    setUp(() {
      productDs = _StubProducts();
      orderDs = _StubOrders();
      provider = CounterSaleProvider(productDs, orderDs);
    });

    testWidgets('sin overflow en ancho iPhone sin teclado', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_hostCounterApp(provider));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Aplicar'), findsNothing);
      expect(find.byKey(const Key('counter-finalize-sale')), findsNothing);
    });
  });

  group('HostCounterSaleTicketScreen layout', () {
    late _StubProducts productDs;
    late _StubOrders orderDs;
    late CounterSaleProvider provider;

    setUp(() {
      productDs = _StubProducts();
      orderDs = _StubOrders();
      provider = CounterSaleProvider(productDs, orderDs);
    });

    testWidgets('semántica Aplicar en ticket', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      productDs.products = [
        Product(
          id: '1',
          name: 'Té',
          description: '',
          price: 30,
          effectivePrice: 30,
          puntosValor: 5,
          category: 'General',
          imageUrl: '',
        ),
      ];
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(product: productDs.products.first);

      await tester.pumpWidget(
        _hostCounterApp(
          provider,
          home: const HostCounterSaleTicketScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Se verificará al finalizar la venta.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('counter-socio-code')), 'eva');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(provider.socioCodigo, 'eva');
      expect(find.text('Código aplicado'), findsOneWidget);
      expect(find.text('Validar'), findsNothing);
    });

    testWidgets('error submit conserva carrito y forma de pago', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      productDs.products = [
        Product(
          id: '1',
          name: 'Té',
          description: '',
          price: 30,
          effectivePrice: 30,
          puntosValor: 5,
          category: 'General',
          imageUrl: '',
        ),
      ];
      await provider.init(clubId: 1, hubId: 1);
      provider.addProductLine(product: productDs.products.first);
      provider.setTipoPago(CounterSalePaymentTypes.efectivo);
      orderDs.shouldFail = true;

      await tester.pumpWidget(
        _hostCounterApp(
          provider,
          home: const HostCounterSaleTicketScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('counter-finalize-sale')));
      await tester.tap(find.byKey(const Key('counter-finalize-sale')));
      await tester.pumpAndSettle();

      expect(provider.cartLines, hasLength(1));
      expect(provider.tipoPago, CounterSalePaymentTypes.efectivo);
      expect(provider.submitError, isNotNull);
    });
  });
}
