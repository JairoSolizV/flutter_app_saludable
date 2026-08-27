import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_google_auth_service.dart';
import 'fake_user_repository.dart';
import 'in_memory_secure_storage_gateway.dart';

class _FakeGoogleWithToken extends FakeGoogleAuthService {
  @override
  Future<String?> signIn() async => 'google-id-token';
}

class _AdminAwareFakeAuthRemote implements AuthRemoteDataSource {
  Object? loginError;
  Object? googleError;
  Object? getMeError;
  User? loginResult;

  @override
  Future<bool> checkEmailExists(String email) async => false;

  @override
  Future<User> getMe() async {
    if (getMeError != null) throw getMeError!;
    return loginResult ??
        User(id: '1', name: 'Host', email: 'host@test.com', role: 'host');
  }

  @override
  Future<User> login(String email, String password) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<User> loginWithGoogle(String idToken) async {
    if (googleError != null) throw googleError!;
    return loginResult!;
  }

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
}

void main() {
  const fakeJwt = 'fake.jwt.token.value';
  const adminBlockedMessage =
      'La app móvil no está disponible para administradores. Usa el panel web.';

  User hostUser({String? token}) => User(
        id: '42',
        name: 'Host User',
        email: 'host@test.com',
        role: 'host',
        token: token ?? fakeJwt,
      );

  group('ADMIN-MOB-001 AuthProvider', () {
    late InMemorySecureStorageGateway storage;
    late SecureTokenStore tokenStore;
    late FakeUserRepository users;
    late _AdminAwareFakeAuthRemote remote;
    late FakeGoogleAuthService googleAuth;
    late AuthProvider auth;

    setUp(() async {
      storage = InMemorySecureStorageGateway();
      tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
      users = FakeUserRepository();
      remote = _AdminAwareFakeAuthRemote();
      googleAuth = _FakeGoogleWithToken();
      auth = AuthProvider(
        remote,
        users,
        tokenStore,
        sessionMigrator: SessionTokenMigrator(
          tokenStore: tokenStore,
          userRepository: users,
        ),
        googleAuthService: googleAuth,
      );
    });

    test('login ADMIN no persiste token ni usuario', () async {
      remote.loginError = AdminMobileNotSupportedException();

      final ok = await auth.login('admin@test.com', 'secret');

      expect(ok, isFalse);
      expect(tokenStore.getToken(), isNull);
      expect(users.current, isNull);
      expect(auth.currentUser, isNull);
      expect(auth.errorMessage, adminBlockedMessage);
      expect(users.saveUserCalls, 0);
    });

    test('loginWithGoogle ADMIN no persiste token ni usuario', () async {
      remote.googleError = AdminMobileNotSupportedException();

      final ok = await auth.loginWithGoogle();

      expect(ok, isFalse);
      expect(tokenStore.getToken(), isNull);
      expect(users.current, isNull);
      expect(auth.currentUser, isNull);
      expect(auth.errorMessage, adminBlockedMessage);
    });

    test('bootstrap legacy host local + /auth/me ADMIN limpia sesión',
        () async {
      users.current = User(
        id: '99',
        name: 'Legacy Admin',
        email: 'admin@test.com',
        role: 'host',
      );
      await tokenStore.saveToken(fakeJwt);
      remote.getMeError = AdminMobileNotSupportedException();

      final session = await auth.bootstrapSession();

      expect(session, isNull);
      expect(auth.currentUser, isNull);
      expect(tokenStore.getToken(), isNull);
      expect(users.current, isNull);
      expect(users.logoutCalls, greaterThanOrEqualTo(1));
      expect(auth.errorMessage, adminBlockedMessage);
    });

    test('login ANFITRION sigue persistiendo sesión host', () async {
      remote.loginResult = hostUser();

      final ok = await auth.login('host@test.com', 'secret');

      expect(ok, isTrue);
      expect(tokenStore.getToken(), fakeJwt);
      expect(users.current, isNotNull);
      expect(users.current!.role, 'host');
      expect(auth.currentUser!.role, 'host');
    });

    test('bootstrap ANFITRION con getMe OK restaura sesión host', () async {
      users.current = User(
        id: '42',
        name: 'Host User',
        email: 'host@test.com',
        role: 'host',
      );
      await tokenStore.saveToken(fakeJwt);
      remote.loginResult = hostUser(token: fakeJwt);

      final session = await auth.bootstrapSession();

      expect(session, isNotNull);
      expect(session!.role, 'host');
      expect(session.token, fakeJwt);
    });
  });
}
