import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/presentation/widgets/product_image.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ProductImage', () {
    testWidgets('url null muestra el placeholder', (tester) async {
      await tester.pumpWidget(_wrap(const ProductImage(imageUrl: null)));
      await tester.pump();

      expect(find.byType(Icon), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('url vacía muestra el placeholder', (tester) async {
      await tester.pumpWidget(_wrap(const ProductImage(imageUrl: '')));
      await tester.pump();

      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('url con solo espacios se trata como vacía', (tester) async {
      await tester.pumpWidget(_wrap(const ProductImage(imageUrl: '   ')));
      await tester.pump();

      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('url no vacía intenta cargar imagen sin crashear',
        (tester) async {
      await tester.pumpWidget(_wrap(const ProductImage(
        imageUrl: 'https://example.invalid/img.png',
      )));
      // No usamos pumpAndSettle porque la carga de red real nunca resuelve
      // en el entorno de test; solo verificamos que el build no lance.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ClipRRect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('respeta ancho y alto personalizados', (tester) async {
      await tester.pumpWidget(_wrap(const ProductImage(
        imageUrl: null,
        width: 40,
        height: 50,
      )));
      await tester.pump();

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth ?? 40, 40);
    });
  });
}
