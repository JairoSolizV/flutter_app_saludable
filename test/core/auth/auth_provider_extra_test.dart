import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/auth/session_status.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_repository.dart';
import 'in_memory_secure_storage_gateway.dart';

class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  bool emailExists = false;
  Object? checkEmailError;

  bool verifySuccess = true;
  User? verifyUserResult;
  Object? verifyError;

  bool resendResult = true;
  Object? resendError;

  User? loginResult;
  Object? loginError;

  User? registerResult;
  Object? registerError;

  User? getMeResult;
  Object? getMeError;
  int getMeCalls = 0;

  User? updateUserResult;
  Object? updateUserError;
  int updateUserCalls = 0;

  @override
  Future<bool> checkEmailExists(String email) async {
    if (checkEmailError != null) throw checkEmailError!;
    return emailExists;
  }

  @override
  Future<User> getMe() async {
    getMeCalls++;
    if (getMeError != null) throw getMeError!;
    return getMeResult!;
  }

  @override
  Future<User> login(String email, String password) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<User> loginWithGoogle(String idToken) async {
    if (loginError != null) throw loginError!;
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
  }) async {
    if (registerError != null) throw registerError!;
    return registerResult!;
  }

  @override
  Future<bool> resendVerificationCode(String email) async {
    if (resendError != null) throw resendError!;
    return resendResult;
  }

  @override
  Future<User> updateUser(User user) async {
    updateUserCalls++;
    if (updateUserError != null) throw updateUserError!;
    return updateUserResult ?? user;
  }

  @override
  Future<User?> verifyEmail(String email, String code) async {
    if (verifyError != null) throw verifyError!;
    if (!verifySuccess) return null;
    return verifyUserResult ??
        User(
          id: '99',
          name: 'Verified User',
          email: email,
          role: 'basic_user',
          token: 'fake.jwt.token.value',
        );
  }
}

void main() {
  const fakeJwt = 'fake.jwt.token.value';

  User user({
    String id = '42',
    String name = 'Test User',
    String email = 'test@example.com',
    String role = 'member',
    String? token,
  }) {
    return User(id: id, name: name, email: email, role: role, token: token);
  }

  group('AuthProvider - flujos adicionales', () {
    late InMemorySecureStorageGateway storage;
    late SecureTokenStore tokenStore;
    late FakeUserRepository users;
    late _FakeAuthRemoteDataSource remote;
    late SessionOwner sessionOwner;
    late SessionStateResetter resetter;
    late AuthProvider auth;

    setUp(() async {
      storage = InMemorySecureStorageGateway();
      tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
      users = FakeUserRepository();
      remote = _FakeAuthRemoteDataSource();
      sessionOwner = SessionOwner();
      resetter = SessionStateResetter();
      auth = AuthProvider(
        remote,
        users,
        tokenStore,
        sessionMigrator: SessionTokenMigrator(
          tokenStore: tokenStore,
          userRepository: users,
        ),
        sessionOwner: sessionOwner,
        sessionStateResetter: resetter,
      );
    });

    test('checkEmailExists retorna true si el backend confirma existencia',
        () async {
      remote.emailExists = true;
      expect(await auth.checkEmailExists('a@b.com'), isTrue);
    });

    test('checkEmailExists retorna false si el backend lanza error',
        () async {
      remote.checkEmailError = ServerException('boom');
      expect(await auth.checkEmailExists('a@b.com'), isFalse);
    });

    test('verifyEmail exitoso limpia requiresVerification', () async {
      remote.registerResult = user(token: fakeJwt);
      await auth.register('N', 'A', 'n@a.com', 'secretpw', '70000000');
      expect(auth.requiresVerification, isTrue);

      remote.verifySuccess = true;
      final ok = await auth.verifyEmail('n@a.com', '1234');

      expect(ok, isTrue);
      expect(auth.requiresVerification, isFalse);
      expect(auth.isLoading, isFalse);
    });

    test('verifyEmail fallido conserva mensaje de código inválido',
        () async {
      remote.verifySuccess = false;
      final ok = await auth.verifyEmail('n@a.com', '0000');

      expect(ok, isFalse);
      expect(auth.errorMessage, contains('inválido'));
    });

    test('verifyEmail con excepción de red setea mensaje público',
        () async {
      remote.verifyError = ServerException('Error de verificación');
      final ok = await auth.verifyEmail('n@a.com', '1234');

      expect(ok, isFalse);
      expect(auth.errorMessage, isNotNull);
    });

    test('resendCode exitoso retorna true sin error', () async {
      remote.resendResult = true;
      final ok = await auth.resendCode('n@a.com');
      expect(ok, isTrue);
      expect(auth.errorMessage, isNull);
    });

    test('resendCode con excepción retorna false y setea error', () async {
      remote.resendError = ServerException('No se pudo reenviar');
      final ok = await auth.resendCode('n@a.com');
      expect(ok, isFalse);
      expect(auth.errorMessage, isNotNull);
    });

    test('login fallido muestra mensaje público y no persiste sesión',
        () async {
      remote.loginError = UnauthorizedException('Credenciales inválidas');

      final ok = await auth.login('a@b.com', 'wrongpw');

      expect(ok, isFalse);
      expect(auth.errorMessage, contains('inválidas'));
      expect(auth.currentUser, isNull);
      expect(tokenStore.getToken(), isNull);
    });

    test('login con email no verificado marca requiresVerification sin sesión',
        () async {
      remote.loginError = EmailNotVerifiedException(
        'Debes verificar tu correo para continuar.',
      );

      final ok = await auth.login('pendiente@test.com', 'secretpw');

      expect(ok, isFalse);
      expect(auth.requiresVerification, isTrue);
      expect(auth.errorMessage, contains('verificar'));
      expect(auth.currentUser, isNull);
      expect(tokenStore.getToken(), isNull);
    });

    test('login con ForbiddenException genérico no marca requiresVerification',
        () async {
      remote.loginError = ForbiddenException(
        'Usuario deshabilitado. Contacte al administrador.',
      );

      final ok = await auth.login('off@test.com', 'secretpw');

      expect(ok, isFalse);
      expect(auth.requiresVerification, isFalse);
      expect(auth.errorMessage, contains('deshabilitado'));
      expect(auth.currentUser, isNull);
      expect(tokenStore.getToken(), isNull);
    });

    test('syncProfile actualiza currentUser conservando el token de sesión',
        () async {
      remote.loginResult = user(token: fakeJwt);
      await auth.login('a@b.com', 'secretpw');

      remote.getMeResult = user(name: 'Nombre Actualizado');
      await auth.syncProfile();

      expect(auth.currentUser?.name, 'Nombre Actualizado');
      expect(auth.currentUser?.token, fakeJwt);
      expect(users.saveUserCalls, greaterThanOrEqualTo(1));
    });

    test('syncProfile con error no lanza y conserva el usuario previo',
        () async {
      remote.loginResult = user(token: fakeJwt, name: 'Original');
      await auth.login('a@b.com', 'secretpw');

      remote.getMeError = ServerException('Fallo al sincronizar');

      await auth.syncProfile();

      expect(auth.currentUser?.name, 'Original');
    });

    test('updateProfile actualiza perfil local y en memoria', () async {
      remote.loginResult = user(token: fakeJwt, name: 'Antes');
      await auth.login('a@b.com', 'secretpw');

      remote.updateUserResult = user(token: null, name: 'Después');
      await auth.updateProfile(name: 'Después');

      expect(auth.currentUser?.name, 'Después');
      expect(auth.currentUser?.token, fakeJwt);
      expect(auth.isLoading, isFalse);
    });

    test('updateProfile sin usuario actual no llama al remoto', () async {
      await auth.updateProfile(name: 'X');
      expect(remote.updateUserCalls, 0);
    });

    test('updateProfile con error relanza la excepción', () async {
      remote.loginResult = user(token: fakeJwt);
      await auth.login('a@b.com', 'secretpw');
      remote.updateUserError = ServerException('Fallo al actualizar');

      await expectLater(
        () => auth.updateProfile(name: 'Nuevo'),
        throwsA(isA<ServerException>()),
      );
      expect(auth.isLoading, isFalse);
    });

    test('clearLocalSessionForExpiration limpia sesión, token y perfil',
        () async {
      remote.loginResult = user(token: fakeJwt);
      await auth.login('a@b.com', 'secretpw');
      expect(sessionOwner.userId, isNotNull);

      await auth.clearLocalSessionForExpiration();

      expect(auth.currentUser, isNull);
      expect(auth.sessionStatus, SessionStatus.expired);
      expect(tokenStore.getToken(), isNull);
      expect(users.current, isNull);
      expect(sessionOwner.userId, isNull);
    });

    test('clearError limpia el mensaje de error previo', () async {
      remote.loginError = UnauthorizedException('Credenciales inválidas');
      await auth.login('a@b.com', 'bad');
      expect(auth.errorMessage, isNotNull);

      auth.clearError();

      expect(auth.errorMessage, isNull);
    });
  });
}
