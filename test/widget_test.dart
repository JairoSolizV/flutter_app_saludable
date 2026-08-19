import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/app.dart';
import 'package:flutter_app_saludable/core/di/app_dependencies.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_app_dependencies.dart';

void main() {
  testWidgets('NutriLifeApp smoke con dependencias fake', (tester) async {
    late AppDependencies deps;
    await tester.runAsync(() async {
      deps = await buildTestDependencies();
    });
    addTearDown(deps.dispose);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: Text('Expande'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      NutriLifeApp(dependencies: deps, router: router),
    );
    await tester.pump();

    expect(find.text('Expande'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
