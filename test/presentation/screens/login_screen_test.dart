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

import '../../core/auth/fake_user_repository.dart';
import '../../core/auth/in_memory_secure_storage_gateway.dart';

class _LoginTrackingRemote implements AuthRemoteDataSource {
  int loginCalls = 0;
  String? lastPassword;

  @override
  Future<User> login(String email, String password) async {
    loginCalls++;
    lastPassword = password;
    return User(
      id: '1',
      name: 'Test User',
      email: email,
      role: 'basic_user',
      token: 'jwt-test',
    );
  }

  @override
  Future<User> getMe() async => User(
        id: '1',
        name: 'Test User',
        email: 'user@test.com',
        role: 'basic_user',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_LoginTrackingRemote> _pumpLoginScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final storage = InMemorySecureStorageGateway();
  final tokenStore = SecureTokenStore(storage: storage);
  await tokenStore.initialize();
  final users = FakeUserRepository();
  final remote = _LoginTrackingRemote();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(remote, users, tokenStore),
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
  return remote;
}

Finder _passwordField(WidgetTester tester) =>
    find.byType(TextFormField).at(1);

Finder _passwordVisibilityButton(WidgetTester tester) => find.descendant(
      of: _passwordField(tester),
      matching: find.byType(IconButton),
    );

bool _isPasswordObscured(WidgetTester tester) {
  final editable = tester.widget<EditableText>(
    find.descendant(
      of: _passwordField(tester),
      matching: find.byType(EditableText),
    ),
  );
  return editable.obscureText;
}

void main() {
  group('LoginScreen UI-AUTH-002', () {
    testWidgets('inicia con contraseña oculta', (tester) async {
      await _pumpLoginScreen(tester);
      expect(_isPasswordObscured(tester), isTrue);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('tap ojo alterna obscureText true → false → true', (tester) async {
      await _pumpLoginScreen(tester);

      await tester.tap(_passwordVisibilityButton(tester));
      await tester.pump();
      expect(_isPasswordObscured(tester), isFalse);
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      await tester.tap(_passwordVisibilityButton(tester));
      await tester.pump();
      expect(_isPasswordObscured(tester), isTrue);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('toggle ojo no altera el texto ingresado', (tester) async {
      await _pumpLoginScreen(tester);

      await tester.enterText(_passwordField(tester), 'MiSecret123');
      await tester.tap(_passwordVisibilityButton(tester));
      await tester.pump();

      expect(find.text('MiSecret123'), findsOneWidget);
      expect(_isPasswordObscured(tester), isFalse);

      await tester.tap(_passwordVisibilityButton(tester));
      await tester.pump();
      expect(_isPasswordObscured(tester), isTrue);
      await tester.tap(_passwordVisibilityButton(tester));
      await tester.pump();
      expect(find.text('MiSecret123'), findsOneWidget);
    });

    testWidgets('login sigue enviando la contraseña ingresada', (tester) async {
      final remote = await _pumpLoginScreen(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'user@test.com');
      await tester.enterText(_passwordField(tester), 'MiSecret123');
      await tester.tap(find.text('INGRESAR'));
      await tester.pumpAndSettle();

      expect(remote.loginCalls, 1);
      expect(remote.lastPassword, 'MiSecret123');
    });
  });
}
