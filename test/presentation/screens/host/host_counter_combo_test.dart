import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/data/datasources/remote/combo_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/combo.dart';
import 'package:flutter_app_saludable/domain/entities/combo_cart_item.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_app_saludable/presentation/providers/counter_sale_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/host/host_counter_sale_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/host/host_counter_sale_ticket_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/member/member_combo_detail_screen.dart';
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
  @override
  Future<void> createCounterSale({
    required int clubId,
    required String tipoPago,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> combos = const [],
  }) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubCombos extends ComboRemoteDataSource {
  _StubCombos() : super(Dio());

  List<Combo> combos = const [];

  @override
  Future<List<Combo>> getCombosByClub(int clubId) async => combos;
}

Combo _combo({double price = 35, bool activo = true}) => Combo(
      id: 1,
      clubId: 1,
      nombre: 'Combo desayuno',
      price: price,
      puntosValor: 15,
      activo: activo,
      items: [
        ComboItem(productoId: 7, productoNombre: 'Batido de leche'),
        ComboItem(productoId: 2, productoNombre: 'Té Energético'),
      ],
    );

Product _batidoProduct() => Product(
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

Widget _app(CounterSaleProvider provider, {Widget? home}) {
  return ChangeNotifierProvider<CounterSaleProvider>.value(
    value: provider,
    child: MaterialApp(
      home: home ?? const HostCounterSaleScreen(clubId: 1, hubId: 10),
    ),
  );
}

void main() {
  group('HostCounterSaleScreen combos', () {
    late _StubProducts productDs;
    late _StubOrders orderDs;
    late _StubCombos comboDs;
    late CounterSaleProvider provider;

    setUp(() {
      productDs = _StubProducts();
      orderDs = _StubOrders();
      comboDs = _StubCombos();
      provider = CounterSaleProvider(productDs, orderDs, comboDs);
    });

    Future<void> openCombosTab(WidgetTester tester) async {
      await tester.drag(find.byType(TabBar), const Offset(-250, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Combos'));
      await tester.pumpAndSettle();
    }

    Future<void> pumpCatalog(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      comboDs.combos = [_combo()];
      productDs.products = [_batidoProduct()];
      await provider.init(clubId: 1, hubId: 10);
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();
      await openCombosTab(tester);
    }

    testWidgets('tab Combos lista combo activo con precio', (tester) async {
      await pumpCatalog(tester);

      expect(find.text('Combo desayuno'), findsOneWidget);
      expect(find.textContaining('35'), findsWidgets);
      expect(find.text('Combos — disponible próximamente'), findsNothing);
      expect(find.byKey(const Key('add-combo-1')), findsOneWidget);
    });

    testWidgets('combo precio 0 no permite agregar', (tester) async {
      comboDs.combos = [_combo(price: 0)];
      productDs.products = [_batidoProduct()];
      await provider.init(clubId: 1, hubId: 10);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();
      await openCombosTab(tester);

      expect(find.text('Precio no configurado'), findsOneWidget);
      final button = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(const Key('add-combo-1')),
          matching: find.byType(InkWell),
        ),
      );
      expect(button.onTap, isNull);
    });

    testWidgets('tap + abre configurador combo', (tester) async {
      await pumpCatalog(tester);

      await tester.tap(find.byKey(const Key('add-combo-1')));
      await tester.pumpAndSettle();

      expect(find.byType(MemberComboDetailScreen), findsOneWidget);
      expect(find.text('Agregar al ticket'), findsOneWidget);
      expect(find.text('Sabor'), findsNothing);
    });
  });

  group('HostCounterSaleTicketScreen combos', () {
    testWidgets('muestra línea combo con componentes', (tester) async {
      final provider =
          CounterSaleProvider(_StubProducts(), _StubOrders(), _StubCombos());
      await provider.init(clubId: 1, hubId: 10);
      provider.addComboLine(
        ComboCartItem(
          comboId: 1,
          comboName: 'Combo desayuno',
          price: 35,
          points: 15,
          quantity: 1,
          components: const [
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
        ),
      );

      await tester.pumpWidget(
        _app(provider, home: const HostCounterSaleTicketScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMBOS'), findsOneWidget);
      expect(find.text('Combo desayuno'), findsOneWidget);
      expect(find.textContaining('Frutilla'), findsOneWidget);
      expect(find.textContaining('Bs 35'), findsWidgets);
    });
  });
}
