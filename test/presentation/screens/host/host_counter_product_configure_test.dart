import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/constants/counter_sale_payment_types.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_app_saludable/domain/entities/product_option.dart';
import 'package:flutter_app_saludable/presentation/screens/host/host_counter_product_configure_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HostCounterProductConfigureSheet', () {
    Product configurableProduct() => Product(
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

    testWidgets('bloquea agregar si falta opción obligatoria', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostCounterProductConfigureSheet(
              product: configurableProduct(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('host-counter-config-add'));
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    });

    testWidgets('selección válida habilita agregar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostCounterProductConfigureSheet(
              product: configurableProduct(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Frutilla'));
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('host-counter-config-add'));
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    });
  });

  group('CounterSalePaymentTypes', () {
    test('valores coinciden con backend V21', () {
      expect(
        CounterSalePaymentTypes.backendValues,
        ['EFECTIVO', 'TRANSFERENCIA', 'QR', 'TARJETA', 'OTRO'],
      );
    });
  });
}
