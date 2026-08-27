import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_google_auth_service.dart';
import 'fake_user_repository.dart';
import 'in_memory_secure_storage_gateway.dart';

class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  User? loginResult;

  @override
  Future<bool> checkEmailExists(String email) async => false;

  @override
  Future<User> getMe() async =>
      User(id: '1', name: 'A B', email: 'a@b.com', role: 'member');

  @override
  Future<User> login(String email, String password) async => loginResult!;

  @override
  Future<User> loginWithGoogle(String idToken) async => loginResult!;

  @override
  Future<User> register(
    String nombre,
    String apellido,
    String email,
    String password,
    String telefono, {
    int? rolId,
  }) async =>
      loginResult!;

  @override
  Future<bool> resendVerificationCode(String email) async => true;

  @override
  Future<User> updateUser(User user) async => user;

  @override
  Future<User?> verifyEmail(String email, String code) async => loginResult;

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<String> verifyPasswordResetCode(String email, String code) async =>
      'reset-token-stub';

  @override
  Future<void> resetPassword(String resetToken, String password) async {}
}

void main() {
  const fakeJwt = 'fake.jwt.token.value';

  User userWithToken() {
    return User(
      id: '42',
      name: 'Test User',
      email: 'test@example.com',
      role: 'member',
      token: fakeJwt,
    );
  }

  group('AUTH-022 logout Google Sign-In', () {
    late InMemorySecureStorageGateway storage;
    late SecureTokenStore tokenStore;
    late FakeUserRepository users;
    late _FakeAuthRemoteDataSource remote;
    late FakeGoogleAuthService googleAuth;
    late AuthProvider auth;

    setUp(() async {
      storage = InMemorySecureStorageGateway();
      tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
      users = FakeUserRepository();
      remote = _FakeAuthRemoteDataSource();
      googleAuth = FakeGoogleAuthService();
      auth = AuthProvider(
        remote,
        users,
        tokenStore,
        googleAuthService: googleAuth,
        sessionMigrator: SessionTokenMigrator(
          tokenStore: tokenStore,
          userRepository: users,
        ),
      );
    });

    Future<void> loginSession() async {
      remote.loginResult = userWithToken();
      await auth.login('test@example.com', 'secret');
    }

    test('logout llama GoogleAuthService.signOut exactamente una vez', () async {
      await loginSession();

      await auth.logout();

      expect(googleAuth.signOutCalls, 1);
    });

    test('logout elimina JWT y perfil local', () async {
      await loginSession();

      await auth.logout();

      expect(tokenStore.getToken(), isNull);
      expect(storage.containsKey(kNutrilifeJwtStorageKey), isFalse);
      expect(users.current, isNull);
      expect(auth.currentUser, isNull);
    });

    test('signOut fallido no impide limpiar sesión local', () async {
      googleAuth.throwOnSignOut = true;
      await loginSession();

      await auth.logout();

      expect(googleAuth.signOutCalls, 1);
      expect(tokenStore.getToken(), isNull);
      expect(users.current, isNull);
      expect(auth.currentUser, isNull);
    });

    test('clearLocalSessionForExpiration no llama Google signOut', () async {
      await loginSession();
      expect(googleAuth.signOutCalls, 0);

      await auth.clearLocalSessionForExpiration();

      expect(googleAuth.signOutCalls, 0);
      expect(tokenStore.getToken(), isNull);
      expect(users.current, isNull);
    });
  });
}
