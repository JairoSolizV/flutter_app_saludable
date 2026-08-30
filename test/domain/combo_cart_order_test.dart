import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/domain/entities/combo.dart';
import 'package:flutter_app_saludable/domain/entities/combo_cart_item.dart';
import 'package:flutter_app_saludable/domain/entities/order_combo.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/core/utils/order_combo_history_display.dart';
import 'package:flutter_app_saludable/domain/entities/order_item_option.dart';
import 'package:flutter_app_saludable/presentation/widgets/order_history_lines.dart';
import 'package:flutter_app_saludable/domain/entities/product_option.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_app_saludable/presentation/screens/member/member_combo_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Combo model', () {
    test('parsea precio del backend', () {
      final combo = Combo.fromMap({
        'id': 1,
        'clubId': 2,
        'nombre': 'Combo',
        'precio': 38,
        'puntosValor': 15,
        'activo': true,
        'items': [],
      });
      expect(combo.price, 38);
      expect(combo.hasConfiguredPrice, isTrue);
    });

    test('legacy sin precio => 0', () {
      final combo = Combo.fromMap({
        'id': 1,
        'clubId': 2,
        'nombre': 'Legacy',
        'activo': true,
        'items': [],
      });
      expect(combo.price, 0);
      expect(combo.hasConfiguredPrice, isFalse);
    });
  });

  group('ComboCartItem identity', () {
    test('configs distintas no colisionan', () {
      final a = ComboCartItem(
        comboId: 4,
        comboName: 'Combo',
        price: 38,
        points: 15,
        quantity: 1,
        components: [
          ComboCartComponent(
            productId: 7,
            productName: 'Batido',
            selections: const [
              ProductOptionSelection(
                groupId: 3,
                groupName: 'Sabores',
                optionId: 6,
                optionName: 'Frutilla',
                quantity: 1,
              ),
            ],
          ),
        ],
      );
      final b = ComboCartItem(
        comboId: 4,
        comboName: 'Combo',
        price: 38,
        points: 15,
        quantity: 1,
        components: [
          ComboCartComponent(
            productId: 7,
            productName: 'Batido',
            selections: const [
              ProductOptionSelection(
                groupId: 3,
                groupName: 'Sabores',
                optionId: 7,
                optionName: 'Cookies',
                quantity: 1,
              ),
            ],
          ),
        ],
      );
      expect(a.configKey, isNot(equals(b.configKey)));
    });
  });

  group('OrderCombo API', () {
    test('toApiMap no incluye precio', () {
      final combo = OrderCombo(
        orderId: 'o1',
        comboId: 4,
        comboName: 'Combo',
        quantity: 2,
        priceSnapshot: 38,
        pointsSnapshot: 15,
        components: [
          OrderComboComponent(
            productId: 7,
            productName: 'Batido',
            options: const [],
          ),
        ],
      );
      final map = combo.toApiMap();
      expect(map['comboId'], 4);
      expect(map.containsKey('precio'), isFalse);
    });
  });

  group('MemberComboDetailScreen', () {
    testWidgets('bloquea agregar si falta opción obligatoria', (tester) async {
      final product = Product(
        id: '7',
        name: 'Batido',
        description: '',
        price: 20,
        effectivePrice: 20,
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
      final combo = Combo(
        id: 4,
        clubId: 1,
        nombre: 'Combo',
        price: 38,
        puntosValor: 15,
        items: [
          ComboItem(productoId: 7, productoNombre: 'Batido'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MemberComboDetailScreen(
            combo: combo,
            productsById: {'7': product},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('combo-add-to-cart'));
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    });
  });

  group('Order history', () {
    test('standaloneItems excluye componentes con pedidoComboId', () {
      final order = {
        'combos': [
          {
            'pedidoComboId': 15,
            'comboId': 4,
            'comboNombre': 'Combo desayuno',
            'cantidad': 1,
            'precioUnitario': 38,
            'subtotal': 38,
            'puntosValor': 15,
            'items': [],
          },
        ],
        'items': [
          {'productoId': 6, 'productoNombre': 'Suelto', 'cantidad': 1},
          {
            'productoId': 7,
            'productoNombre': 'Batido',
            'cantidad': 1,
            'pedidoComboId': 15,
          },
        ],
      };

      final standalone = OrderComboHistoryDisplay.standaloneItems(order);
      expect(standalone, hasLength(1));
      expect(standalone.first['productoNombre'], 'Suelto');
    });

    testWidgets('OrderHistoryLines no duplica combo items', (tester) async {
      final order = {
        'combos': [
          {
            'pedidoComboId': 15,
            'comboNombre': 'Combo desayuno',
            'cantidad': 1,
            'subtotal': 38,
            'items': [
              {
                'productoNombre': 'Batido',
                'opciones': [
                  {
                    'grupoId': 3,
                    'grupoNombre': 'Sabores',
                    'opcionId': 6,
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
            'pedidoComboId': 15,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderHistoryLines(order: order),
          ),
        ),
      );

      expect(find.text('Combo desayuno'), findsOneWidget);
      expect(find.textContaining('Batido'), findsOneWidget);
      expect(find.textContaining('1 x Batido'), findsNothing);
    });
  });
}
