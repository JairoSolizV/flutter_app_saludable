import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_app_saludable/presentation/screens/member/member_product_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({
  double effective = 28.5,
  List<ProductOptionGroup>? groups,
  String description = 'Batido saludable y cremoso',
}) {
  return Product(
    id: '7',
    name: 'Batido de leche',
    description: description,
    price: 28.5,
    effectivePrice: effective,
    puntosValor: 5,
    optionGroups: groups,
  );
}

Widget _app(Product product) {
  return MaterialApp(home: MemberProductDetailScreen(product: product));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('muestra descripción, Bs efectivo y puntos separados',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(_product()));

    expect(find.byKey(const Key('member-product-detail')), findsOneWidget);
    expect(find.text('Batido de leche'), findsOneWidget);
    expect(find.text('Batido saludable y cremoso'), findsOneWidget);
    expect(find.byKey(const Key('detail-effective-price')), findsOneWidget);
    expect(find.text('Bs 28,50'), findsWidgets);
    expect(find.text('5 puntos'), findsOneWidget);
    expect(find.text('PERSONALIZA TU PRODUCTO'), findsNothing);
  });

  testWidgets('tap producto abre ProductDetail', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ListTile(
            title: const Text('Batido de leche'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MemberProductDetailScreen(product: _product()),
                ),
              );
            },
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Batido de leche'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberProductDetailScreen), findsOneWidget);
    expect(find.byKey(const Key('member-product-detail')), findsOneWidget);
    expect(find.text('Agregar al pedido'), findsOneWidget);
  });

  testWidgets('sin precio deshabilita agregar', (tester) async {
    await tester.pumpWidget(_app(_product(effective: 0)));
    expect(find.text('Precio no configurado'), findsWidgets);
    expect(find.text('Este producto todavía no tiene un precio de venta.'),
        findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('add-to-order'))).onPressed,
      isNull,
    );
  });

  testWidgets('cantidad actualiza el total', (tester) async {
    await tester.pumpWidget(_app(_product()));
    expect(find.byKey(const Key('detail-total')), findsOneWidget);
    expect(find.text('Bs 28,50'), findsWidgets);

    await tester.tap(find.byKey(const Key('product-qty-plus')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Bs 57,00'), findsOneWidget);
  });

  testWidgets('producto con opciones usa selector y no llama sabores',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final product = _product(groups: [
      ProductOptionGroup(
        id: 2,
        name: 'Sabores',
        minSelections: 1,
        maxSelections: 1,
        options: [
          ProductOption(id: 3, name: 'Frutilla', orden: 0),
          ProductOption(id: 4, name: 'Cookies', orden: 1),
        ],
      ),
    ]);
    ProductCartAddResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await Navigator.push<ProductCartAddResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberProductDetailScreen(product: product),
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('PERSONALIZA TU PRODUCTO'), findsOneWidget);
    expect(find.text('Elige 1'), findsOneWidget);
    expect(find.text('Sabor:'), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byKey(const Key('add-to-order'))).onPressed,
      isNull,
    );

    await tester.tap(find.text('Frutilla'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-to-order')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.quantity, 1);
    expect(result!.selections, hasLength(1));
    expect(result!.selections.first.optionId, 3);
    expect(result!.selections.first.optionName, 'Frutilla');
    expect(result!.cartKey, contains('7#'));
  });
}
