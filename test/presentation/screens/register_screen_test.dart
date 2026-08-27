import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/register_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_user_repository.dart';
import '../../core/auth/in_memory_secure_storage_gateway.dart';

class _RegisterTrackingRemote implements AuthRemoteDataSource {
  int registerCalls = 0;
  String? lastPassword;

  @override
  Future<bool> checkEmailExists(String email) async => false;

  @override
  Future<User> register(
    String nombre,
    String apellido,
    String email,
    String password,
    String telefono, {
    int? rolId,
  }) async {
    registerCalls++;
    lastPassword = password;
    return User(
      id: '99',
      name: '$nombre $apellido',
      email: email,
      role: 'basic_user',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_RegisterTrackingRemote> _pumpRegisterScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final storage = InMemorySecureStorageGateway();
  final tokenStore = SecureTokenStore(storage: storage);
  await tokenStore.initialize();
  final users = FakeUserRepository();
  final remote = _RegisterTrackingRemote();

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(remote, users, tokenStore),
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/register',
          routes: [
            GoRoute(
              path: '/register',
              builder: (_, __) => const RegisterScreen(),
            ),
            GoRoute(
              path: '/verify-email',
              builder: (_, __) =>
                  const Scaffold(body: Text('Verify Email Screen')),
            ),
            GoRoute(
              path: '/login',
              builder: (_, __) => const Scaffold(body: Text('Login Screen')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return remote;
}

Future<void> _acceptTerms(WidgetTester tester) async {
  final firstCheckbox = find.byType(CheckboxListTile).first;
  await tester.ensureVisible(firstCheckbox);
  await tester.tap(firstCheckbox);
  await tester.pumpAndSettle();

  final secondCheckbox = find.byType(CheckboxListTile).last;
  await tester.ensureVisible(secondCheckbox);
  await tester.tap(secondCheckbox);
  await tester.pumpAndSettle();
}

Future<void> _fillRegisterForm(
  WidgetTester tester, {
  String password = 'Password123',
  String confirmPassword = 'Password123',
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Juan');
  await tester.enterText(fields.at(1), 'Perez');
  await tester.enterText(fields.at(2), 'nuevo@test.com');
  await tester.enterText(fields.at(3), '71234567');
  await tester.enterText(fields.at(4), password);
  await tester.enterText(fields.at(5), confirmPassword);
  await tester.pumpAndSettle();
}

Future<void> _tapRegister(WidgetTester tester) async {
  final registerButton = find.text('REGISTRARSE');
  await tester.ensureVisible(registerButton);
  await tester.tap(registerButton);
  await tester.pumpAndSettle();
}

void main() {
  group('RegisterScreen CONFIRM-PASS-001', () {
    testWidgets('password = confirmPassword continúa al flujo OTP', (tester) async {
      final remote = await _pumpRegisterScreen(tester);
      await _fillRegisterForm(tester);
      await _acceptTerms(tester);
      await _tapRegister(tester);

      expect(remote.registerCalls, 1);
      expect(remote.lastPassword, 'Password123');
      expect(find.text('Verify Email Screen'), findsOneWidget);
    });

    testWidgets('password != confirmPassword muestra error y no registra',
        (tester) async {
      final remote = await _pumpRegisterScreen(tester);
      await _fillRegisterForm(
        tester,
        password: 'Password123',
        confirmPassword: 'Password999',
      );
      await _acceptTerms(tester);
      await _tapRegister(tester);

      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(remote.registerCalls, 0);
      expect(find.text('Crear Cuenta'), findsOneWidget);
    });

    testWidgets('confirmPassword vacío muestra error y no registra', (tester) async {
      final remote = await _pumpRegisterScreen(tester);
      await _fillRegisterForm(
        tester,
        password: 'Password123',
        confirmPassword: '',
      );
      await _acceptTerms(tester);
      await _tapRegister(tester);

      expect(find.text('Confirma tu contraseña.'), findsOneWidget);
      expect(remote.registerCalls, 0);
    });

    testWidgets('contraseña inválida mantiene reglas actuales', (tester) async {
      final remote = await _pumpRegisterScreen(tester);
      await _fillRegisterForm(
        tester,
        password: 'corta',
        confirmPassword: 'corta',
      );
      await _acceptTerms(tester);
      await _tapRegister(tester);

      expect(
        find.text('La contraseña debe tener al menos 8 caracteres'),
        findsOneWidget,
      );
      expect(remote.registerCalls, 0);
    });

    testWidgets('coincidencia exacta: espacio final falla', (tester) async {
      final remote = await _pumpRegisterScreen(tester);
      await _fillRegisterForm(
        tester,
        password: 'Password123',
        confirmPassword: 'Password123 ',
      );
      await _acceptTerms(tester);
      await _tapRegister(tester);

      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(remote.registerCalls, 0);
    });

    testWidgets('muestra campo Confirmar contraseña debajo de Contraseña',
        (tester) async {
      await _pumpRegisterScreen(tester);

      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Confirmar contraseña'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(6));
    });
  });
}
