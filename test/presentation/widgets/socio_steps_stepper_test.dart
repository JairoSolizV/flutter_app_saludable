import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/presentation/widgets/socio_steps_stepper.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap() => const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SocioStepsStepper()),
      ),
    );

int _currentStep(WidgetTester tester) =>
    tester.widget<Stepper>(find.byType(Stepper)).currentStep;

void main() {
  testWidgets('renderiza dentro de un SingleChildScrollView sin overflow',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Stepper), findsOneWidget);
  });

  testWidgets('arranca en el primer paso', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(_currentStep(tester), 0);
  });

  testWidgets('no muestra "Atrás" en el primer paso', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Atrás'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Siguiente'), findsOneWidget);
  });

  testWidgets('avanza al tocar "Siguiente"', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
    await tester.pumpAndSettle();

    expect(_currentStep(tester), 1);
  });

  testWidgets('retrocede al tocar "Atrás"', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Atrás'));
    await tester.pumpAndSettle();

    expect(_currentStep(tester), 0);
  });

  testWidgets('en el último paso oculta "Siguiente"', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
      await tester.pumpAndSettle();
    }

    expect(_currentStep(tester), 2);
    expect(find.widgetWithText(ElevatedButton, 'Siguiente'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Atrás'), findsOneWidget);
  });

  testWidgets('permite saltar a un paso tocando su cabecera', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registro'));
    await tester.pumpAndSettle();

    expect(_currentStep(tester), 1);
  });
}
