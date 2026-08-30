import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/entities/order_item_option.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderItem.lineKey / cart identity', () {
    test('misma configuración misma key sin importar orden del array', () {
      const a = OrderItemOption(
        groupId: 4,
        optionId: 9,
        quantity: 1,
        groupName: 'Consistencia',
        optionName: 'Cremoso',
      );
      const b = OrderItemOption(
        groupId: 3,
        optionId: 6,
        quantity: 1,
        groupName: 'Sabores',
        optionName: 'Frutilla',
      );
      final k1 = OrderItem.lineKey(productId: '7', options: [a, b]);
      final k2 = OrderItem.lineKey(productId: '7', options: [b, a]);
      expect(k1, k2);
      expect(k1, '7#3:6:1|4:9:1');
    });

    test('config distinta → key distinta', () {
      const frutilla = OrderItemOption(groupId: 3, optionId: 6, quantity: 1);
      const cookies = OrderItemOption(groupId: 3, optionId: 7, quantity: 1);
      final k1 = OrderItem.lineKey(productId: '7', options: [frutilla]);
      final k2 = OrderItem.lineKey(productId: '7', options: [cookies]);
      expect(k1, isNot(k2));
    });

    test('repeat quantity cambia key', () {
      const x1 = OrderItemOption(groupId: 3, optionId: 6, quantity: 1);
      const x2 = OrderItemOption(groupId: 3, optionId: 6, quantity: 2);
      expect(
        OrderItem.lineKey(productId: '7', options: [x1]),
        isNot(OrderItem.lineKey(productId: '7', options: [x2])),
      );
    });

    test('nombres distintos con mismos IDs → misma key', () {
      const a = OrderItemOption(
        groupId: 3,
        optionId: 6,
        quantity: 1,
        groupName: 'Sabores',
        optionName: 'Frutilla',
      );
      const b = OrderItemOption(
        groupId: 3,
        optionId: 6,
        quantity: 1,
        groupName: 'Sabor',
        optionName: 'Strawberry',
      );
      expect(
        OrderItem.lineKey(productId: '7', options: [a]),
        OrderItem.lineKey(productId: '7', options: [b]),
      );
    });

    test('producto sin opciones usa solo productId', () {
      expect(OrderItem.lineKey(productId: '7', options: const []), '7');
    });
  });

  group('OrderItemOption API', () {
    test('toApiMap solo ids y cantidad', () {
      const opt = OrderItemOption(
        groupId: 3,
        groupName: 'Sabores',
        optionId: 6,
        optionName: 'Frutilla',
        quantity: 2,
      );
      expect(opt.toApiMap(), {
        'grupoId': 3,
        'opcionId': 6,
        'cantidad': 2,
      });
      expect(opt.toApiMap().containsKey('grupoNombre'), isFalse);
    });

    test('parse response snapshot tolera ids null', () {
      final opt = OrderItemOption.fromApiJson({
        'grupoId': null,
        'grupoNombre': 'Sabores',
        'grupoOrden': 0,
        'opcionId': null,
        'opcionNombre': 'Frutilla',
        'opcionOrden': 0,
        'cantidad': 1,
      });
      expect(opt.groupId, isNull);
      expect(opt.groupName, 'Sabores');
      expect(opt.optionName, 'Frutilla');
    });

    test('listFromApi vacío si missing', () {
      expect(OrderItemOption.listFromApi(null), isEmpty);
      expect(OrderItemOption.listFromApi([]), isEmpty);
    });
  });

  group('ProductOptionSelection → OrderItemOption', () {
    test('conserva ids para sync', () {
      const sel = ProductOptionSelection(
        groupId: 3,
        groupName: 'Sabores',
        groupOrder: 0,
        optionId: 6,
        optionName: 'Frutilla',
        optionOrder: 0,
        quantity: 1,
      );
      expect(sel.toOrderItemOption().hasRequiredIds, isTrue);
      expect(sel.hasRequiredIds, isTrue);
    });
  });
}
