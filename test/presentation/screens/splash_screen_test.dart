import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/di/app_dependencies.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../helpers/test_app_dependencies.dart';

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/guest-home',
        builder: (_, __) => const Scaffold(body: Text('Guest Home')),
      ),
      GoRoute(
        path: '/host-dashboard',
        builder: (_, __) => const Scaffold(body: Text('Host Dashboard')),
      ),
      GoRoute(
        path: '/basic-home',
        builder: (_, __) => const Scaffold(body: Text('Basic Home')),
      ),
      GoRoute(
        path: '/member-home',
        builder: (_, __) => const Scaffold(body: Text('Member Home')),
      ),
    ],
  );
}

void main() {
  testWidgets('muestra el splash y navega a guest-home sin sesión previa',
      (tester) async {
    late AppDependencies deps;
    await tester.runAsync(() async {
      deps = await buildTestDependencies();
    });
    addTearDown(deps.dispose);

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
        child: MaterialApp.router(routerConfig: _buildRouter()),
      ),
    );

    expect(find.text('Nutrilife Club'), findsOneWidget);
    expect(find.text('Club de Nutrición'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Completa el Future.delayed(2s) del splash.
    await tester.pump(const Duration(seconds: 3));

    // bootstrapSession usa sqflite (async real): alternar runAsync + pump
    // hasta que GoRouter navegue a guest-home.
    for (var i = 0; i < 50; i++) {
      if (find.text('Guest Home').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(find.text('Guest Home'), findsOneWidget);
  });
}
