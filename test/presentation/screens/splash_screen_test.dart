import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/di/app_dependencies.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
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
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login')),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, __) => const Scaffold(body: Text('Verify Email')),
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
  testWidgets('muestra el splash y navega a login sin sesión ni pending',
      (tester) async {
    late AppDependencies deps;
    await tester.runAsync(() async {
      deps = await buildTestDependencies();
    });
    addTearDown(deps.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              deps.authRemoteDataSource,
              deps.userRepository,
              deps.tokenStore,
              pendingVerificationStore: deps.pendingVerificationStore,
              sessionExpirationHandler: deps.sessionExpirationHandler,
              sessionOwner: deps.sessionOwner,
              sessionStateResetter: deps.sessionStateResetter,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => UserProvider(deps.userRepository),
          ),
        ],
        child: MaterialApp.router(routerConfig: _buildRouter()),
      ),
    );

    expect(find.text('Expande'), findsNothing);
    expect(
      find.text('Asistencia por QR, pedidos y puntos de socio'),
      findsNothing,
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 3));

    for (var i = 0; i < 50; i++) {
      if (find.text('Login').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('navega a verify-email si hay pending email sin sesión',
      (tester) async {
    late AppDependencies deps;
    await tester.runAsync(() async {
      deps = await buildTestDependencies();
      await deps.pendingVerificationStore.save('cold@test.com');
    });
    addTearDown(deps.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              deps.authRemoteDataSource,
              deps.userRepository,
              deps.tokenStore,
              pendingVerificationStore: deps.pendingVerificationStore,
              sessionExpirationHandler: deps.sessionExpirationHandler,
              sessionOwner: deps.sessionOwner,
              sessionStateResetter: deps.sessionStateResetter,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => UserProvider(deps.userRepository),
          ),
        ],
        child: MaterialApp.router(routerConfig: _buildRouter()),
      ),
    );

    await tester.pump(const Duration(seconds: 3));

    for (var i = 0; i < 50; i++) {
      if (find.text('Verify Email').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(find.text('Verify Email'), findsOneWidget);
  });
}
