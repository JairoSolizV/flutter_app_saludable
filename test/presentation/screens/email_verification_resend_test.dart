import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/sqlite_pending_verification_store.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/auth/email_verification_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_user_repository.dart';
import '../../core/auth/in_memory_secure_storage_gateway.dart';

class _ResendTrackingRemote implements AuthRemoteDataSource {
  int resendCalls = 0;
  Completer<void>? gate;
  Object? resendError;
  bool resendResult = true;

  @override
  Future<bool> resendVerificationCode(String email) async {
    resendCalls++;
    if (gate != null) {
      await gate!.future;
    }
    if (resendError != null) throw resendError!;
    return resendResult;
  }

  @override
  Future<bool> checkEmailExists(String email) => throw UnimplementedError();

  @override
  Future<User> getMe() => throw UnimplementedError();

  @override
  Future<User> login(String email, String password) => throw UnimplementedError();

  @override
  Future<User> loginWithGoogle(String idToken) => throw UnimplementedError();

  @override
  Future<User> register(
    String nombre,
    String apellido,
    String email,
    String password,
    String telefono, {
    int? rolId,
  }) =>
      throw UnimplementedError();

  @override
  Future<User?> verifyEmail(String email, String code) =>
      throw UnimplementedError();

  @override
  Future<void> requestPasswordReset(String email) => throw UnimplementedError();

  @override
  Future<String> verifyPasswordResetCode(String email, String code) =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword(String token, String password) =>
      throw UnimplementedError();

  @override
  Future<User> updateUser(User user) => throw UnimplementedError();
}

Widget _buildApp(AuthProvider auth) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: const MaterialApp(
      home: EmailVerificationScreen(email: 'user@test.com'),
    ),
  );
}

void main() {
  late _ResendTrackingRemote remote;
  late AuthProvider auth;

  setUp(() {
    remote = _ResendTrackingRemote();
    final tokenStore = SecureTokenStore(
      storage: InMemorySecureStorageGateway(),
    );
    auth = AuthProvider(
      remote,
      FakeUserRepository(),
      tokenStore,
      pendingVerificationStore: InMemoryPendingVerificationStore(),
      sessionMigrator: SessionTokenMigrator(
        tokenStore: tokenStore,
        userRepository: FakeUserRepository(),
      ),
    );
  });

  testWidgets('triple tap rápido produce una sola llamada resend',
      (tester) async {
    remote.gate = Completer<void>();

    await tester.pumpWidget(_buildApp(auth));
    await tester.pump();

    final button = find.text('Reenviar Código');
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(remote.resendCalls, 1);
    expect(find.textContaining('Reenviar en'), findsNothing);

    remote.gate!.complete();
    await tester.pumpAndSettle();

    expect(remote.resendCalls, 1);
    expect(find.textContaining('Reenviar en 60s'), findsOneWidget);
  });

  testWidgets('cooldown backend 37 inicia contador en 37', (tester) async {
    remote.resendError = OtpResendCooldownException(retryAfterSeconds: 37);

    await tester.pumpWidget(_buildApp(auth));
    await tester.pump();

    await tester.tap(find.text('Reenviar Código'));
    await tester.pumpAndSettle();

    expect(find.text('Reenviar en 37s'), findsOneWidget);
    expect(auth.otpResendRetryAfterSeconds, 37);
  });

  testWidgets('error normal no deja botón bloqueado permanentemente',
      (tester) async {
    remote.resendError = ServerException('Fallo temporal');

    await tester.pumpWidget(_buildApp(auth));
    await tester.pump();

    await tester.tap(find.text('Reenviar Código'));
    await tester.pumpAndSettle();

    expect(find.text('Reenviar Código'), findsOneWidget);
  });

  testWidgets('timer se cancela en dispose sin setState after dispose',
      (tester) async {
    await tester.pumpWidget(_buildApp(auth));
    await tester.pump();

    await tester.tap(find.text('Reenviar Código'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reenviar en'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
