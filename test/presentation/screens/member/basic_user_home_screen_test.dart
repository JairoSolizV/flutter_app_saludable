import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/di/app_dependencies.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/member/basic_user_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../helpers/test_app_dependencies.dart';

final _user = User(
  id: '42',
  name: 'Ana Pérez',
  email: 'ana@example.com',
  role: 'basic_user',
);

Widget _buildApp(AppDependencies deps) {
  final userProvider = UserProvider(deps.userRepository)..setUser(_user);

  final router = GoRouter(
    initialLocation: '/basic-home',
    routes: [
      GoRoute(
        path: '/basic-home',
        builder: (_, __) => const BasicUserHomeScreen(),
      ),
      GoRoute(
        path: '/basic-profile',
        builder: (_, __) => const Scaffold(body: Text('Perfil Básico')),
      ),
    ],
  );

  return ChangeNotifierProvider<UserProvider>.value(
    value: userProvider,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late AppDependencies deps;

  setUp(() async {
    deps = await buildTestDependencies();
  });

  tearDown(() {
    deps.dispose();
  });

  testWidgets('saluda al usuario por su nombre', (tester) async {
    await tester.pumpWidget(_buildApp(deps));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('no muestra el icono de notificaciones', (tester) async {
    await tester.pumpWidget(_buildApp(deps));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_none), findsNothing);
  });

  testWidgets('no muestra el botón de clubes cercanos', (tester) async {
    await tester.pumpWidget(_buildApp(deps));
    await tester.pumpAndSettle();

    expect(find.text('Buscar Clubes Cercanos'), findsNothing);
  });

  testWidgets('no muestra la sección de tips de nutrición', (tester) async {
    await tester.pumpWidget(_buildApp(deps));
    await tester.pumpAndSettle();

    expect(find.text('Tips de Nutrición'), findsNothing);
  });

  testWidgets('mantiene la card del QR de activación', (tester) async {
    await tester.pumpWidget(_buildApp(deps));
    await tester.pumpAndSettle();

    expect(
      find.text('Muestra este QR al anfitrión para unirte'),
      findsOneWidget,
    );
  });

  testWidgets('el avatar del AppBar navega al perfil', (tester) async {
    await tester.pumpWidget(_buildApp(deps));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('basic-home-profile-avatar')));
    await tester.pumpAndSettle();

    expect(find.text('Perfil Básico'), findsOneWidget);
  });
}
