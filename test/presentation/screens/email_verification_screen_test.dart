import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/di/app_dependencies.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/email_verification_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../helpers/test_app_dependencies.dart';

/// Anchos lógicos representativos. 385 es el del móvil donde se reportó el
/// desbordamiento de 63px en la fila de los 6 dígitos.
const _anchos = <double>[320, 360, 385, 411, 768];

void main() {
  for (final ancho in _anchos) {
    testWidgets('la fila de dígitos no desborda a $ancho px de ancho',
        (tester) async {
      late AppDependencies deps;
      await tester.runAsync(() async {
        deps = await buildTestDependencies();
      });
      addTearDown(deps.dispose);

      tester.view.physicalSize = Size(ancho, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            deps.authRemoteDataSource,
            deps.userRepository,
            deps.tokenStore,
            sessionExpirationHandler: deps.sessionExpirationHandler,
            sessionOwner: deps.sessionOwner,
            sessionStateResetter: deps.sessionStateResetter,
          ),
          child: const MaterialApp(
            home: EmailVerificationScreen(email: 'bcndn@gmail.com'),
          ),
        ),
      );
      await tester.pump();

      // Un RenderFlex desbordado registra una excepción de layout; si la fila
      // se sale de la pantalla, esto la captura.
      expect(tester.takeException(), isNull);

      // Las 6 casillas siguen presentes y dentro de los límites de la pantalla.
      final casillas = find.byType(TextField);
      expect(casillas, findsNWidgets(6));

      final primera = tester.getRect(casillas.first);
      final ultima = tester.getRect(casillas.last);
      expect(primera.left, greaterThanOrEqualTo(0));
      expect(ultima.right, lessThanOrEqualTo(ancho));
    });
  }
}
