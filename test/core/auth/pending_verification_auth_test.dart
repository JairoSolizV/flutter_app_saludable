import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_app_saludable/core/auth/sqlite_pending_verification_store.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_repository.dart';
import 'in_memory_secure_storage_gateway.dart';

class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  User? loginResult;
  Object? loginError;

  User? registerResult;
  Object? registerError;

  User? verifyUserResult;
  bool verifySuccess = true;

  User? googleLoginResult;

  @override
  Future<bool> checkEmailExists(String email) async => false;

  @override
  Future<User> getMe() async => throw UnimplementedError();

  @override
  Future<User> login(String email, String password) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<User> loginWithGoogle(String idToken) async {
    return googleLoginResult ??
        User(
          id: 'g1',
          name: 'Google User',
          email: 'google@test.com',
          role: 'basic_user',
          token: 'google-jwt',
        );
  }

  @override
  Future<User> register(
    String nombre,
    String apellido,
    String email,
    String password,
    String telefono, {
    int? rolId,
  }) async {
    if (registerError != null) throw registerError!;
    return registerResult ??
        User(
          id: '99',
          name: '$nombre $apellido',
          email: email,
          role: 'basic_user',
        );
  }

  @override
  Future<bool> resendVerificationCode(String email) async => true;

  @override
  Future<User> updateUser(User user) async => user;

  @override
  Future<User?> verifyEmail(String email, String code) async {
    if (!verifySuccess) return null;
    return verifyUserResult ??
        User(
          id: '99',
          name: 'Verified',
          email: email,
          role: 'basic_user',
          token: 'verify-jwt',
        );
  }
}

void main() {
  const fakeJwt = 'session.jwt.token';

  group('AUTH-013 pending verification email', () {
    late InMemorySecureStorageGateway storage;
    late SecureTokenStore tokenStore;
    late FakeUserRepository users;
    late _FakeAuthRemoteDataSource remote;
    late InMemoryPendingVerificationStore pendingStore;
    late AuthProvider auth;

    setUp(() async {
      storage = InMemorySecureStorageGateway();
      tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
      users = FakeUserRepository();
      remote = _FakeAuthRemoteDataSource();
      pendingStore = InMemoryPendingVerificationStore();
      auth = AuthProvider(
        remote,
        users,
        tokenStore,
        pendingVerificationStore: pendingStore,
        sessionMigrator: SessionTokenMigrator(
          tokenStore: tokenStore,
          userRepository: users,
        ),
        sessionOwner: SessionOwner(),
        sessionStateResetter: SessionStateResetter(),
      );
    });

    test('registro pendiente guarda email normalizado', () async {
      final ok = await auth.register(
        'Ana',
        'Perez',
        '  USuario@gmail.com ',
        'secret1234',
        '+59170000000',
      );

      expect(ok, isTrue);
      expect(auth.requiresVerification, isTrue);
      expect(await pendingStore.read(), 'usuario@gmail.com');
    });

    test('EMAIL_NOT_VERIFIED desde login guarda email', () async {
      remote.loginError = EmailNotVerifiedException('Debes verificar');

      final ok = await auth.login('  SOCIO1@DEMO.COM  ', 'secret');

      expect(ok, isFalse);
      expect(auth.requiresVerification, isTrue);
      expect(await pendingStore.read(), 'socio1@demo.com');
      expect(tokenStore.getToken(), isNull);
    });

    test('sin sesión y pending email → ruta verify-email', () async {
      await pendingStore.save('pendiente@test.com');

      final route = await auth.resolveColdStartRoute();

      expect(route, '/verify-email');
      expect(await auth.getPendingVerificationEmail(), 'pendiente@test.com');
    });

    test('sesión válida gana sobre pending email antiguo y lo elimina',
        () async {
      await pendingStore.save('viejo@test.com');
      users.current = User(
        id: '1',
        name: 'Activo',
        email: 'activo@test.com',
        role: 'member',
      );
      await tokenStore.saveToken(fakeJwt);

      final user = await auth.bootstrapSession();

      expect(user, isNotNull);
      expect(user!.email, 'activo@test.com');
      expect(await pendingStore.read(), isNull);
    });

    test('verify-email exitoso elimina pending email', () async {
      await pendingStore.save('verify@test.com');
      remote.verifySuccess = true;

      final ok = await auth.verifyEmail('verify@test.com', '123456');

      expect(ok, isTrue);
      expect(await pendingStore.read(), isNull);
      expect(tokenStore.getToken(), 'verify-jwt');
    });

    test('login exitoso elimina pending email (misma ruta que Google Sign-In)',
        () async {
      await pendingStore.save('viejo@test.com');
      remote.loginResult = User(
        id: '1',
        name: 'Activo',
        email: 'activo@test.com',
        role: 'member',
        token: fakeJwt,
      );

      final ok = await auth.login('activo@test.com', 'secret');

      expect(ok, isTrue);
      expect(await pendingStore.read(), isNull);
    });

    test('sin token y sin pending → login', () async {
      final route = await auth.resolveColdStartRoute();
      expect(route, '/login');
      expect(await pendingStore.read(), isNull);
    });

    test('store solo persiste email, no OTP ni contraseña', () async {
      await pendingStore.save('alias+tag@gmail.com');

      final stored = await pendingStore.read();
      expect(stored, 'alias+tag@gmail.com');
      expect(stored!.contains('123456'), isFalse);
      expect(stored.contains('secret'), isFalse);
    });

    test('resendCode conserva email pendiente', () async {
      await pendingStore.clear();
      final ok = await auth.resendCode('  ReSend@test.com  ');

      expect(ok, isTrue);
      expect(await pendingStore.read(), 'resend@test.com');
    });

    test('clearPendingVerificationEmail elimina el valor', () async {
      await pendingStore.save('x@test.com');
      await auth.clearPendingVerificationEmail();
      expect(await pendingStore.read(), isNull);
    });
  });
}
