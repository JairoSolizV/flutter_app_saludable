import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/auth/fake_apple_auth_service.dart';
import '../../core/auth/fake_google_auth_service.dart';
import '../../core/auth/fake_user_repository.dart';
import '../../core/auth/in_memory_secure_storage_gateway.dart';

class _StubRemote implements AuthRemoteDataSource {

  @override
  Future<void> deleteAccount() async => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpLogin(WidgetTester tester) async {
  final users = FakeUserRepository();
  final storage = InMemorySecureStorageGateway();
  final tokenStore = SecureTokenStore(storage: storage);
  await tokenStore.initialize();

  final auth = AuthProvider(
    _StubRemote(),
    users,
    tokenStore,
    googleAuthService: FakeGoogleAuthService(),
    appleAuthService: FakeAppleAuthService(credentials: null),
  );
  final userProvider = UserProvider(users);

  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/guest-home',
        builder: (_, __) => const Scaffold(body: Text('Guest')),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const Scaffold(body: Text('Register')),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const Scaffold(body: Text('Forgot')),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: userProvider),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('iOS muestra botón oficial de Apple y Google', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pumpLogin(tester);
      expect(find.byType(SignInWithAppleButton), findsOneWidget);
      expect(find.text('Iniciar con Google'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android no muestra Sign in with Apple', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await _pumpLogin(tester);
      expect(find.byType(SignInWithAppleButton), findsNothing);
      expect(find.text('Iniciar con Google'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
