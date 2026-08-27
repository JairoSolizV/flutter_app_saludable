import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_repository.dart';
import 'in_memory_secure_storage_gateway.dart';

class _PasswordResetTrackingRemote implements AuthRemoteDataSource {
  int forgotCalls = 0;
  int resendCalls = 0;
  int verifyResetCalls = 0;
  int resetPasswordCalls = 0;
  String? lastResetToken;
  String? lastResetPassword;
  String verifyResetResult = 'opaque-reset-token';
  Object? verifyResetError;
  Object? resetPasswordError;
  bool verifyEmailCalled = false;

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
      User(id: '99', name: '$nombre $apellido', email: email, role: 'basic_user');

  @override
  Future<bool> resendVerificationCode(String email) async {
    resendCalls++;
    return true;
  }

  @override
  Future<User> updateUser(User user) async => user;

  @override
  Future<User?> verifyEmail(String email, String code) async {
    verifyEmailCalled = true;
    return null;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    forgotCalls++;
  }

  @override
  Future<String> verifyPasswordResetCode(String email, String code) async {
    verifyResetCalls++;
    if (verifyResetError != null) throw verifyResetError!;
    return verifyResetResult;
  }

  @override
  Future<void> resetPassword(String resetToken, String password) async {
    resetPasswordCalls++;
    lastResetToken = resetToken;
    lastResetPassword = password;
    if (resetPasswordError != null) throw resetPasswordError!;
  }
}

void main() {
  late InMemorySecureStorageGateway storage;
  late SecureTokenStore tokenStore;
  late FakeUserRepository users;
  late _PasswordResetTrackingRemote remote;
  late AuthProvider auth;

  setUp(() async {
    storage = InMemorySecureStorageGateway();
    tokenStore = SecureTokenStore(storage: storage);
    await tokenStore.initialize();
    users = FakeUserRepository();
    remote = _PasswordResetTrackingRemote();
    auth = AuthProvider(
      remote,
      users,
      tokenStore,
      sessionMigrator: SessionTokenMigrator(
        tokenStore: tokenStore,
        userRepository: users,
      ),
    );
  });

  test('requestPasswordReset llama forgot-password y no crea sesión', () async {
    final ok = await auth.requestPasswordReset('user@test.com');
    expect(ok, isTrue);
    expect(remote.forgotCalls, 1);
    expect(auth.currentUser, isNull);
    expect(tokenStore.getToken(), isNull);
  });

  test('verifyPasswordResetCode guarda token solo en memoria', () async {
    final ok = await auth.verifyPasswordResetCode('user@test.com', '123456');
    expect(ok, isTrue);
    expect(auth.canCompletePasswordReset, isTrue);
    expect(tokenStore.getToken(), isNull);
    expect(auth.currentUser, isNull);
    expect(remote.verifyResetCalls, 1);
    expect(remote.verifyEmailCalled, isFalse);
  });

  test('verifyPasswordResetCode inválido muestra mensaje genérico', () async {
    remote.verifyResetError = ResetCodeInvalidException();
    final ok = await auth.verifyPasswordResetCode('user@test.com', '000000');
    expect(ok, isFalse);
    expect(auth.canCompletePasswordReset, isFalse);
    expect(auth.errorMessage, ResetCodeInvalidException.defaultMessage);
  });

  test('completePasswordReset envía token+password y limpia estado', () async {
    await auth.verifyPasswordResetCode('user@test.com', '123456');
    final ok = await auth.completePasswordReset('NewPass123!');
    expect(ok, isTrue);
    expect(remote.resetPasswordCalls, 1);
    expect(remote.lastResetToken, 'opaque-reset-token');
    expect(remote.lastResetPassword, 'NewPass123!');
    expect(auth.canCompletePasswordReset, isFalse);
    expect(auth.currentUser, isNull);
    expect(tokenStore.getToken(), isNull);
  });

  test('RESET_TOKEN_INVALID limpia token y expone código', () async {
    await auth.verifyPasswordResetCode('user@test.com', '123456');
    remote.resetPasswordError = ResetTokenInvalidException();
    final ok = await auth.completePasswordReset('NewPass123!');
    expect(ok, isFalse);
    expect(auth.canCompletePasswordReset, isFalse);
    expect(auth.passwordResetErrorCode, ResetTokenInvalidException.errorCode);
    expect(auth.errorMessage, ResetTokenInvalidException.defaultMessage);
  });

  test('clearPasswordResetState elimina token efímero', () async {
    await auth.verifyPasswordResetCode('user@test.com', '123456');
    auth.clearPasswordResetState();
    expect(auth.canCompletePasswordReset, isFalse);
  });

  test('re-request password reset usa forgot-password no resend-code', () async {
    await auth.requestPasswordReset('user@test.com');
    await auth.requestPasswordReset('user@test.com');
    expect(remote.forgotCalls, 2);
    expect(remote.resendCalls, 0);
  });

  test('login normal sigue funcionando tras flujo reset', () async {
    await auth.verifyPasswordResetCode('user@test.com', '123456');
    auth.clearPasswordResetState();
    final ok = await auth.login('user@test.com', 'secret');
    expect(ok, isTrue);
    expect(auth.currentUser, isNotNull);
  });
}
