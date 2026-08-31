import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/forgot_password_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/login_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/new_password_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/reset_password_code_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_user_repository.dart';
import '../../core/auth/in_memory_secure_storage_gateway.dart';

class _FlowTrackingRemote implements AuthRemoteDataSource {
  int forgotCalls = 0;
  int resendCalls = 0;
  int verifyResetCalls = 0;
  int resetPasswordCalls = 0;
  String? lastResetPassword;
  bool verifyResetShouldSucceed = true;
  bool resetShouldSucceed = true;

  @override
  Future<bool> checkEmailExists(String email) async => false;

  @override
  Future<User> getMe() async =>
      User(id: '1', name: 'A B', email: 'a@b.com', role: 'member');

  @override
  Future<User> login(String email, String password) async =>
      User(id: '1', name: 'A B', email: email, role: 'member', token: 'jwt');

  @override
  Future<User> loginWithGoogle(String idToken) async =>
      User(id: '1', name: 'G', email: 'g@t.com', role: 'member', token: 'jwt');

  @override
  Future<User> register(
    String nombre,
    String apellido,
    String email,
    String password,
    String telefono, {
    int? rolId,
  }) async =>
      User(id: '99', name: 'N', email: email, role: 'basic_user');

  @override
  Future<bool> resendVerificationCode(String email) async {
    resendCalls++;
    return true;
  }

  @override
  Future<User> updateUser(User user) async => user;

  @override
  Future<User?> verifyEmail(String email, String code) async => null;

  @override
  Future<void> requestPasswordReset(String email) async {
    forgotCalls++;
  }

  @override
  Future<String> verifyPasswordResetCode(String email, String code) async {
    verifyResetCalls++;
    if (!verifyResetShouldSucceed) {
      throw ResetCodeInvalidException();
    }
    return 'flow-reset-token';
  }

  @override
  Future<void> resetPassword(String resetToken, String password) async {
    resetPasswordCalls++;
    lastResetPassword = password;
    if (!resetShouldSucceed) {
      throw ResetTokenInvalidException();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(_FlowTrackingRemote remote, AuthProvider auth)> _pumpWithRouter(
  WidgetTester tester, {
  String initialLocation = '/login',
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final storage = InMemorySecureStorageGateway();
  final tokenStore = SecureTokenStore(storage: storage);
  await tokenStore.initialize();
  final users = FakeUserRepository();
  final remote = _FlowTrackingRemote();
  final auth = AuthProvider(remote, users, tokenStore);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => auth,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: [
            GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
            GoRoute(
              path: '/forgot-password',
              builder: (_, __) => const ForgotPasswordScreen(),
            ),
            GoRoute(
              path: '/reset-password-code',
              builder: (_, state) {
                final extra = state.extra as Map<String, dynamic>?;
                return ResetPasswordCodeScreen(
                  email: extra?['email'] as String?,
                );
              },
            ),
            GoRoute(
              path: '/new-password',
              builder: (_, __) => const NewPasswordScreen(),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (remote, auth);
}

void main() {
  testWidgets('Login muestra link ¿Olvidaste tu contraseña?', (tester) async {
    await _pumpWithRouter(tester);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('INGRESAR'), findsOneWidget);

    // El link queda debajo de INGRESAR en el árbol (después en orden de pintura).
    final ingresarY = tester.getTopLeft(find.text('INGRESAR')).dy;
    final linkY = tester.getTopLeft(find.text('¿Olvidaste tu contraseña?')).dy;
    expect(linkY, greaterThan(ingresarY));

    // Centrado horizontalmente (sin Align right).
    final screenWidth = tester.getSize(find.byType(MaterialApp)).width;
    final linkCenterX = tester.getCenter(find.text('¿Olvidaste tu contraseña?')).dx;
    expect((linkCenterX - screenWidth / 2).abs(), lessThan(24));
  });

  testWidgets('Link navega a forgot-password', (tester) async {
    await _pumpWithRouter(tester);
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();
    expect(find.text('Recuperar contraseña'), findsOneWidget);
  });

  testWidgets('link forgot no desborda en ancho angosto', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpWithRouter(tester);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Email inválido no llama request', (tester) async {
    final pair = await _pumpWithRouter(tester, initialLocation: '/forgot-password');
    await tester.enterText(find.byType(TextFormField), 'no-es-email');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();
    expect(pair.$1.forgotCalls, 0);
  });

  testWidgets('Forgot válido llama endpoint y navega a OTP', (tester) async {
    final pair = await _pumpWithRouter(tester, initialLocation: '/forgot-password');
    await tester.enterText(find.byType(TextFormField), 'user@test.com');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
    expect(pair.$1.forgotCalls, 1);
    expect(find.text('Código de recuperación'), findsOneWidget);
  });

  testWidgets('OTP correcto navega a new-password con token en memoria',
      (tester) async {
    final pair = await _pumpWithRouter(tester, initialLocation: '/forgot-password');
    await tester.enterText(find.byType(TextFormField), 'user@test.com');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '${i + 1}');
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(pair.$1.verifyResetCalls, 1);
    expect(pair.$2.canCompletePasswordReset, isTrue);
    expect(find.byType(NewPasswordScreen), findsOneWidget);
  });

  testWidgets('OTP incorrecto muestra mensaje y no navega', (tester) async {
    final pair = await _pumpWithRouter(tester, initialLocation: '/forgot-password');
    pair.$1.verifyResetShouldSucceed = false;
    await tester.enterText(find.byType(TextFormField), 'user@test.com');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '0');
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.textContaining('Código inválido o expirado'), findsOneWidget);
    expect(find.text('Nueva contraseña'), findsNothing);
  });

  testWidgets('Reenviar llama forgot-password no resend-code', (tester) async {
    final pair = await _pumpWithRouter(tester, initialLocation: '/forgot-password');
    await tester.enterText(find.byType(TextFormField), 'user@test.com');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reenviar código'));
    await tester.pumpAndSettle();
    expect(pair.$1.forgotCalls, 2);
    expect(pair.$1.resendCalls, 0);
  });

  testWidgets('Password mismatch no envía reset-password', (tester) async {
    final pair = await _pumpWithRouter(tester, initialLocation: '/forgot-password');
    await _goToNewPasswordScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'NewPass123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'OtherPass123!');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pump();
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(pair.$1.resetPasswordCalls, 0);
  });

  testWidgets('Confirmación vacía muestra error', (tester) async {
    await _pumpWithRouter(tester, initialLocation: '/forgot-password');
    await _goToNewPasswordScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'NewPass123!');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pump();
    expect(find.text('Confirma tu contraseña.'), findsOneWidget);
  });

  testWidgets('Reset exitoso limpia token y vuelve a login', (tester) async {
    final pair = await _pumpWithRouter(tester, initialLocation: '/forgot-password');
    await _goToNewPasswordScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'NewPass123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NewPass123!');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pumpAndSettle();

    expect(pair.$1.resetPasswordCalls, 1);
    expect(pair.$1.lastResetPassword, 'NewPass123!');
    expect(pair.$2.canCompletePasswordReset, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('new-password sin token redirige a forgot-password', (tester) async {
    await _pumpWithRouter(tester, initialLocation: '/new-password');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  });
}

Future<void> _goToNewPasswordScreen(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField), 'user@test.com');
  await tester.tap(find.text('Enviar código'));
  await tester.pumpAndSettle();

  final fields = find.byType(TextField);
  for (var i = 0; i < 6; i++) {
    await tester.enterText(fields.at(i), '${i + 1}');
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(find.byType(NewPasswordScreen), findsOneWidget);
}
