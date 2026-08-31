import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_google_auth_service.dart';
import '../../core/auth/fake_user_repository.dart';
import '../../core/auth/in_memory_secure_storage_gateway.dart';

class _GoogleLoginRemote implements AuthRemoteDataSource {
  @override
  Future<User> loginWithGoogle(String idToken) async => User(
        id: '1',
        name: 'Google User',
        email: 'google@test.com',
        role: 'basic_user',
        token: 'jwt-google',
      );

  @override
  Future<User> getMe() async => User(
        id: '1',
        name: 'Google User',
        email: 'google@test.com',
        role: 'basic_user',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpLoginScreen(
  WidgetTester tester,
  FakeGoogleAuthService google,
) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final storage = InMemorySecureStorageGateway();
  final tokenStore = SecureTokenStore(storage: storage);
  await tokenStore.initialize();
  final users = FakeUserRepository();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            _GoogleLoginRemote(),
            users,
            tokenStore,
            googleAuthService: google,
          ),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider(users)),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
            GoRoute(
              path: '/basic-home',
              builder: (_, __) => const Scaffold(body: Text('Basic Home')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _googleButton() =>
    find.widgetWithText(OutlinedButton, 'Iniciar con Google');

void main() {
  group('LoginScreen UI-001 — teclado y login con Google', () {
    testWidgets('el teclado ya está cerrado cuando se abre el selector de Google',
        (tester) async {
      bool? tecladoVisibleDuranteSignIn;
      final google = FakeGoogleAuthService(
        idToken: 'google-id-token',
        onSignIn: () async {
          tecladoVisibleDuranteSignIn = tester.testTextInput.isVisible;
        },
      );

      await _pumpLoginScreen(tester, google);

      // El usuario estaba escribiendo el correo antes de tocar el botón.
      await tester.showKeyboard(find.byType(TextFormField).first);
      await tester.pump();
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'el escenario debe partir con el teclado abierto',
      );

      await tester.tap(_googleButton());
      await tester.pumpAndSettle();

      expect(google.signInCalls, 1);
      expect(
        tecladoVisibleDuranteSignIn,
        isFalse,
        reason:
            'UI-001: si el campo sigue enfocado, Android reabre el teclado al '
            'volver del selector nativo y queda sobre la pantalla destino',
      );
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Basic Home'), findsOneWidget);
    });

    testWidgets(
        'si el usuario cancela, el teclado queda cerrado y seguimos en login',
        (tester) async {
      final google = FakeGoogleAuthService(idToken: null);

      await _pumpLoginScreen(tester, google);

      await tester.showKeyboard(find.byType(TextFormField).first);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(_googleButton());
      await tester.pumpAndSettle();

      expect(google.signInCalls, 1);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Basic Home'), findsNothing);
      expect(_googleButton(), findsOneWidget);
    });
  });
}
