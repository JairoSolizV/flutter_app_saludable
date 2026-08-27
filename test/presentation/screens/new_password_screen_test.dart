import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/new_password_screen.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_user_repository.dart';
import '../../core/auth/in_memory_secure_storage_gateway.dart';

class _ResetTrackingRemote implements AuthRemoteDataSource {
  int resetPasswordCalls = 0;
  String? lastResetPassword;

  @override
  Future<String> verifyPasswordResetCode(String email, String code) async =>
      'reset-token-test';

  @override
  Future<void> resetPassword(String resetToken, String password) async {
    resetPasswordCalls++;
    lastResetPassword = password;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(_ResetTrackingRemote remote, AuthProvider auth)> _pumpNewPasswordScreen(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final storage = InMemorySecureStorageGateway();
  final tokenStore = SecureTokenStore(storage: storage);
  await tokenStore.initialize();
  final users = FakeUserRepository();
  final remote = _ResetTrackingRemote();
  final auth = AuthProvider(remote, users, tokenStore);
  await auth.verifyPasswordResetCode('user@test.com', '123456');

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/new-password',
          routes: [
            GoRoute(
              path: '/new-password',
              builder: (_, __) => const NewPasswordScreen(),
            ),
            GoRoute(
              path: '/login',
              builder: (_, __) => const LoginScreen(),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (remote, auth);
}

Finder passwordField(WidgetTester tester) =>
    find.byType(TextFormField).at(0);

Finder confirmPasswordField(WidgetTester tester) =>
    find.byType(TextFormField).at(1);

Finder visibilityButtonFor(WidgetTester tester, Finder field) =>
    find.descendant(of: field, matching: find.byType(IconButton));

bool isObscured(WidgetTester tester, Finder field) {
  final editable = tester.widget<EditableText>(
    find.descendant(of: field, matching: find.byType(EditableText)),
  );
  return editable.obscureText;
}

void main() {
  group('NewPasswordScreen UI-AUTH-002', () {
    testWidgets('ambos campos inician ocultos', (tester) async {
      await _pumpNewPasswordScreen(tester);

      expect(isObscured(tester, passwordField(tester)), isTrue);
      expect(isObscured(tester, confirmPasswordField(tester)), isTrue);
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(2));
    });

    testWidgets('toggle de nueva contraseña alterna obscureText', (tester) async {
      await _pumpNewPasswordScreen(tester);
      final field = passwordField(tester);

      await tester.tap(visibilityButtonFor(tester, field));
      await tester.pump();
      expect(isObscured(tester, field), isFalse);

      await tester.tap(visibilityButtonFor(tester, field));
      await tester.pump();
      expect(isObscured(tester, field), isTrue);
    });

    testWidgets('toggle de confirmación es independiente', (tester) async {
      await _pumpNewPasswordScreen(tester);
      final pass = passwordField(tester);
      final confirm = confirmPasswordField(tester);

      await tester.tap(visibilityButtonFor(tester, pass));
      await tester.pump();
      expect(isObscured(tester, pass), isFalse);
      expect(isObscured(tester, confirm), isTrue);

      await tester.tap(visibilityButtonFor(tester, confirm));
      await tester.pump();
      expect(isObscured(tester, pass), isFalse);
      expect(isObscured(tester, confirm), isFalse);
    });

    testWidgets('toggle ojo no altera el texto ingresado', (tester) async {
      await _pumpNewPasswordScreen(tester);
      final field = passwordField(tester);

      await tester.enterText(field, 'NewPass123!');
      await tester.tap(visibilityButtonFor(tester, field));
      await tester.pump();

      expect(find.text('NewPass123!'), findsOneWidget);
    });

    testWidgets('reset envía solo password sin confirmPassword', (tester) async {
      final pair = await _pumpNewPasswordScreen(tester);

      await tester.enterText(passwordField(tester), 'NewPass123!');
      await tester.enterText(confirmPasswordField(tester), 'NewPass123!');
      await tester.tap(find.text('Actualizar contraseña'));
      await tester.pumpAndSettle();

      expect(pair.$1.resetPasswordCalls, 1);
      expect(pair.$1.lastResetPassword, 'NewPass123!');
    });
  });
}
