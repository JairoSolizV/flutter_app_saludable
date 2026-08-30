import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductPrices / fromMap', () {
    test('parse precio, precioEfectivo y precioVentaClub', () {
      final p = Product.fromMap({
        'id': 7,
        'nombre': 'Batido',
        'precio': 28.0,
        'precioVentaClub': 30.5,
        'precioEfectivo': 30.5,
      });
      expect(p.price, 28.0);
      expect(p.clubSalePrice, 30.5);
      expect(p.effectivePrice, 30.5);
      expect(p.hasConfiguredSalePrice, isTrue);
    });

    test('fallback payload viejo: sin precioEfectivo usa precio', () {
      final p = Product.fromMap({
        'id': 8,
        'nombre': 'Té',
        'precio': 12,
      });
      expect(p.price, 12.0);
      expect(p.clubSalePrice, isNull);
      expect(p.effectivePrice, 12.0);
    });

    test('sin precio cae a 0', () {
      final p = Product.fromMap({'id': 1, 'nombre': 'X'});
      expect(p.price, 0.0);
      expect(p.effectivePrice, 0.0);
      expect(p.hasConfiguredSalePrice, isFalse);
    });

    test('SQLite toMap solo persiste price base', () {
      final p = Product(
        id: '1',
        name: 'A',
        description: '',
        price: 28.5,
        effectivePrice: 30,
        clubSalePrice: 30,
      );
      final map = p.toMap();
      expect(map['price'], 28.5);
      expect(map.containsKey('effectivePrice'), isFalse);
      expect(map.containsKey('clubSalePrice'), isFalse);
      expect(map.containsKey('precioEfectivo'), isFalse);

      final round = Product.fromMap(map);
      expect(round.price, 28.5);
      expect(round.effectivePrice, 28.5);
      expect(round.clubSalePrice, isNull);
    });

    test('acepta price en inglés (legacy SQLite)', () {
      final p = Product.fromMap({
        'id': '5',
        'name': 'Batido',
        'description': '',
        'price': 12,
      });
      expect(p.price, 12.0);
      expect(p.effectivePrice, 12.0);
    });
  });

  group('ProductCartAddResult identidad', () {
    test('configuraciones distintas no colisionan', () {
      final product = Product(
        id: '7',
        name: 'Batido de leche',
        description: '',
        price: 28,
        effectivePrice: 28,
      );
      const frutilla = ProductOptionSelection(
        groupId: 2,
        groupName: 'Sabores',
        optionId: 3,
        optionName: 'Frutilla',
        quantity: 1,
      );
      const cookies = ProductOptionSelection(
        groupId: 2,
        groupName: 'Sabores',
        optionId: 4,
        optionName: 'Cookies',
        quantity: 1,
      );
      final a = ProductCartAddResult(
        product: product,
        quantity: 2,
        selections: const [frutilla],
      );
      final b = ProductCartAddResult(
        product: product,
        quantity: 1,
        selections: const [cookies],
      );
      expect(a.cartKey, isNot(b.cartKey));
      expect(a.cartKey, contains('7#'));
      expect(a.cartKey, isNot(contains('Batido')));
      expect(a.subtotal, 56.0);
      expect(a.optionsSummary, 'Frutilla');
    });
  });
}
