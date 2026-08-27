import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_repository.dart';
import 'in_memory_secure_storage_gateway.dart';

class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  User? loginResult;
  User? registerResult;

  @override
  Future<bool> checkEmailExists(String email) async => false;

  @override
  Future<User> getMe() async {
    return User(id: '1', name: 'A B', email: 'a@b.com', role: 'member');
  }

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
      registerResult!;

  @override
  Future<bool> resendVerificationCode(String email) async => true;

  @override
  Future<User> updateUser(User user) async => user;

  @override
  Future<User?> verifyEmail(String email, String code) async => null;

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

  User userWithToken({String role = 'member'}) {
    return User(
      id: '42',
      name: 'Test User',
      email: 'test@example.com',
      role: role,
      token: fakeJwt,
    );
  }

  group('AuthProvider sesión', () {
    late InMemorySecureStorageGateway storage;
    late SecureTokenStore tokenStore;
    late FakeUserRepository users;
    late FakeAuthRemoteDataSource remote;
    late AuthProvider auth;

    setUp(() async {
      storage = InMemorySecureStorageGateway();
      tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
      users = FakeUserRepository();
      remote = FakeAuthRemoteDataSource();
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

    test('login guarda token seguro y perfil sin token', () async {
      remote.loginResult = userWithToken();

      final ok = await auth.login('test@example.com', 'secret');

      expect(ok, isTrue);
      expect(tokenStore.getToken(), fakeJwt);
      expect(users.current, isNotNull);
      expect(users.current!.token, isNull);
      expect(auth.currentUser!.token, fakeJwt);
    });

    test('logout limpia TokenStore y perfil local', () async {
      remote.loginResult = userWithToken();
      await auth.login('test@example.com', 'secret');

      await auth.logout();

      expect(tokenStore.getToken(), isNull);
      expect(storage.containsKey(kNutrilifeJwtStorageKey), isFalse);
      expect(users.current, isNull);
      expect(auth.currentUser, isNull);
    });

    test('perfil sin token no se considera sesión válida', () async {
      users.current = User(
        id: '42',
        name: 'Test User',
        email: 'test@example.com',
        role: 'member',
      );

      final session = await auth.bootstrapSession();

      expect(session, isNull);
      expect(auth.currentUser, isNull);
    });

    test('token sin perfil se limpia de forma determinista', () async {
      await tokenStore.saveToken(fakeJwt);
      users.current = null;

      final session = await auth.bootstrapSession();

      expect(session, isNull);
      expect(tokenStore.getToken(), isNull);
    });

    test('bootstrap con perfil y token restaura sesión', () async {
      users.current = User(
        id: '42',
        name: 'Test User',
        email: 'test@example.com',
        role: 'host',
      );
      await tokenStore.saveToken(fakeJwt);

      final session = await auth.bootstrapSession();

      expect(session, isNotNull);
      expect(session!.role, 'host');
      expect(session.token, fakeJwt);
    });

    test('registro guarda token seguro y perfil sin JWT en SQLite', () async {
      remote.registerResult = userWithToken(role: 'basic_user');

      final ok = await auth.register(
        'Nombre',
        'Apellido',
        'new@example.com',
        'secret',
        '70000000',
      );

      expect(ok, isTrue);
      expect(tokenStore.getToken(), fakeJwt);
      expect(users.current!.token, isNull);
      expect(auth.requiresVerification, isTrue);
    });
  });

  group('User persistence', () {
    test('toMap nunca incluye JWT', () {
      final user = User(
        id: '1',
        name: 'A',
        email: 'a@b.com',
        role: 'member',
        token: fakeJwt,
      );

      expect(user.toMap()['token'], isNull);
      expect(user.withoutToken().token, isNull);
    });

    test('fromMap ignora columna token legacy', () {
      final user = User.fromMap({
        'id': '1',
        'name': 'A',
        'email': 'a@b.com',
        'role': 'member',
        'token': fakeJwt,
      });

      expect(user.token, isNull);
    });
  });
}
