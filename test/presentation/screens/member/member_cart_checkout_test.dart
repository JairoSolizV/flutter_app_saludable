import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/domain/entities/combo_cart_item.dart';
import 'package:flutter_app_saludable/presentation/screens/member/widgets/member_cart_checkout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  group('MemberCartTotals', () {
    test('totalUnits suma cantidades producto y combo', () {
      expect(
        MemberCartTotals.totalUnits(
          productCart: {'7#3:6:1': 2},
          comboCart: [
            ComboCartItem(
              comboId: 4,
              comboName: 'Combo',
              price: 38,
              points: 15,
              quantity: 1,
              components: const [],
            ),
          ],
        ),
        3,
      );
    });

    test('productCountLabel singular/plural', () {
      expect(MemberCartTotals.productCountLabel(1), '1 producto');
      expect(MemberCartTotals.productCountLabel(3), '3 productos');
    });

    test('totalAmount usa precio efectivo por productId y combo', () {
      final total = MemberCartTotals.totalAmount(
        productCart: {'7#3:6:1|4:9:1': 1},
        unitPriceFor: (pid) => pid == '7' ? 20.0 : 0,
        isPriced: (pid) => pid == '7',
        comboCart: [
          ComboCartItem(
            comboId: 4,
            comboName: 'Combo',
            price: 38,
            points: 15,
            quantity: 2,
            components: const [],
          ),
        ],
      );
      expect(total, 96.0);
    });
  });

  group('MemberCartBar', () {
    testWidgets('muestra Ver carrito, unidades y total', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberCartBar(
              totalUnits: 2,
              totalAmount: 40,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('member-cart-bar')), findsOneWidget);
      expect(find.text('Ver carrito'), findsOneWidget);
      expect(find.textContaining('2 productos'), findsOneWidget);
      expect(find.textContaining('Bs 40,00'), findsOneWidget);
      expect(find.byKey(const Key('member-cart-badge')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('member-cart-badge')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(LucideIcons.shoppingCart), findsOneWidget);
    });

    testWidgets('badge muestra cantidad real y tap dispara callback',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberCartBar(
              totalUnits: 1,
              totalAmount: 20,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('member-cart-badge')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('member-cart-badge')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('member-cart-bar')));
      expect(tapped, isTrue);
    });

    testWidgets('cantidad alta en badge se clamp a 99+', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberCartBar(
              totalUnits: 120,
              totalAmount: 10,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
      expect(find.textContaining('120 productos'), findsOneWidget);
    });
  });

  group('MemberCartCheckoutSheet', () {
    late TextEditingController noteCtrl;

    setUp(() {
      noteCtrl = TextEditingController();
    });

    tearDown(() {
      noteCtrl.dispose();
    });

    Widget sheet({
      required List<MemberCartLineViewModel> lines,
      double total = 40,
      void Function(String key, int delta)? onQty,
      VoidCallback? onCreate,
      bool creating = false,
      String tipo = 'EN_LUGAR',
      ValueChanged<String>? onTipo,
      void Function(String key)? onRemove,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: MemberCartCheckoutSheet(
              lines: lines,
              totalAmount: total,
              tipoConsumo: tipo,
              onTipoConsumoChanged: onTipo ?? (_) {},
              notaController: noteCtrl,
              scrollController: ScrollController(),
              isCreatingOrder: creating,
              onCreateOrder: onCreate ?? () {},
              onQuantityChanged: onQty ?? (_, __) {},
              onRemoveLine: onRemove ?? (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('muestra configs distintas por separado con opciones', (tester) async {
      await tester.pumpWidget(sheet(lines: const [
        MemberCartLineViewModel(
          cartKey: '7#3:6:1|4:9:1',
          productId: '7',
          productName: 'Batido de leche',
          optionsSummary: 'Frutilla · Cremoso',
          quantity: 1,
          unitPrice: 20,
          priced: true,
        ),
        MemberCartLineViewModel(
          cartKey: '7#3:7:1|4:10:1',
          productId: '7',
          productName: 'Batido de leche',
          optionsSummary: 'Cookies · Líquido',
          quantity: 1,
          unitPrice: 20,
          priced: true,
        ),
      ]));

      expect(find.byKey(const Key('member-cart-sheet')), findsOneWidget);
      expect(find.text('Tu pedido'), findsOneWidget);
      expect(find.text('Frutilla · Cremoso'), findsOneWidget);
      expect(find.text('Cookies · Líquido'), findsOneWidget);
      expect(find.text('Batido de leche'), findsNWidgets(2));
    });

    testWidgets('repeat muestra ×2 en resumen', (tester) async {
      await tester.pumpWidget(sheet(lines: const [
        MemberCartLineViewModel(
          cartKey: '7#3:6:2',
          productId: '7',
          productName: 'Batido',
          optionsSummary: 'Frutilla ×2 · Cremoso',
          quantity: 1,
          unitPrice: 20,
          priced: true,
        ),
      ]));
      expect(find.text('Frutilla ×2 · Cremoso'), findsOneWidget);
    });

    testWidgets('total visible y botón Crear pedido', (tester) async {
      await tester.pumpWidget(sheet(total: 40, lines: const []));
      expect(find.byKey(const Key('member-cart-total')), findsOneWidget);
      expect(find.text('Bs 40,00'), findsWidgets);
      expect(find.textContaining('Crear pedido'), findsOneWidget);
      expect(find.text('Crear carrito'), findsNothing);
    });

    testWidgets('nota general conserva valor', (tester) async {
      noteCtrl.text = 'Sin hielo por favor';
      await tester.pumpWidget(sheet(lines: const []));
      expect(find.text('Sin hielo por favor'), findsOneWidget);
    });

    testWidgets('selector En lugar / Para recoger', (tester) async {
      String? selected;
      await tester.pumpWidget(sheet(
        lines: const [],
        onTipo: (v) => selected = v,
      ));
      await tester.tap(find.text('Para recoger'));
      expect(selected, 'PARA_RECOGER');
    });

    testWidgets('cantidad dispara callback', (tester) async {
      String? changedKey;
      int? delta;
      await tester.pumpWidget(sheet(
        lines: const [
          MemberCartLineViewModel(
            cartKey: '7',
            productId: '7',
            productName: 'Batido',
            optionsSummary: '',
            quantity: 1,
            unitPrice: 20,
            priced: true,
          ),
        ],
        onQty: (k, d) {
          changedKey = k;
          delta = d;
        },
      ));
      await tester.tap(find.byIcon(LucideIcons.plus));
      expect(changedKey, '7');
      expect(delta, 1);
    });

    testWidgets('double tap bloqueado durante creación', (tester) async {
      await tester.pumpWidget(sheet(
        lines: const [],
        creating: true,
        onCreate: () {},
      ));
      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('member-create-order-button')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('eliminar dispara onRemoveLine', (tester) async {
      String? removed;
      await tester.pumpWidget(sheet(
        lines: const [
          MemberCartLineViewModel(
            cartKey: '7#3:6:1',
            productId: '7',
            productName: 'Batido',
            optionsSummary: 'Frutilla',
            quantity: 1,
            unitPrice: 20,
            priced: true,
          ),
        ],
        onRemove: (k) => removed = k,
      ));
      await tester.tap(find.byKey(const Key('member-cart-remove-7#3:6:1')));
      expect(removed, '7#3:6:1');
    });
  });
}
