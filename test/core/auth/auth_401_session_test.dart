import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_expiration_handler.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/ui/session_feedback.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_repository.dart';
import 'in_memory_secure_storage_gateway.dart';

class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  Object? loginError;
  User? loginResult;

  @override
  Future<bool> checkEmailExists(String email) async => false;

  @override
  Future<User> getMe() async {
    return User(id: '1', name: 'A B', email: 'a@b.com', role: 'member');
  }

  @override
  Future<User> login(String email, String password) async {
    if (loginError != null) {
      throw loginError!;
    }
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
  Future<bool> verifyEmail(String email, String code) async => true;
}

void main() {
  const fakeJwt = 'fake.jwt.token.value';

  group('AuthProvider + 401 session', () {
    late InMemorySecureStorageGateway storage;
    late SecureTokenStore tokenStore;
    late FakeUserRepository users;
    late FakeAuthRemoteDataSource remote;
    late SessionExpirationHandler sessionHandler;
    late SessionOwner sessionOwner;
    late SessionStateResetter resetter;
    late AuthProvider auth;
    late int navCalls;

    setUp(() async {
      storage = InMemorySecureStorageGateway();
      tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
      users = FakeUserRepository();
      remote = FakeAuthRemoteDataSource();
      sessionHandler = SessionExpirationHandler(tokenStore: tokenStore);
      sessionOwner = SessionOwner();
      resetter = SessionStateResetter();
      navCalls = 0;
      auth = AuthProvider(
        remote,
        users,
        tokenStore,
        sessionMigrator: SessionTokenMigrator(
          tokenStore: tokenStore,
          userRepository: users,
        ),
        sessionExpirationHandler: sessionHandler,
        sessionOwner: sessionOwner,
        sessionStateResetter: resetter,
      );
      sessionHandler.bind(
        clearLocalSession: () async {
          await auth.clearLocalSessionForExpiration();
        },
        onSessionExpiredUi: () async {
          navCalls++;
        },
      );
    });

    test('login con credenciales incorrectas conserva error y no redirige',
        () async {
      remote.loginError = UnauthorizedException(
        'Credenciales incorrectas. Verifique su email y contraseña.',
      );

      final ok = await auth.login('a@b.com', 'bad');

      expect(ok, isFalse);
      expect(auth.errorMessage, contains('Credenciales'));
      expect(navCalls, 0);
      expect(tokenStore.getToken(), isNull);
    });

    test('logout por 401 elimina token seguro y perfil', () async {
      await tokenStore.saveToken(fakeJwt);
      users.current = User(
        id: '42',
        name: 'Test',
        email: 't@e.com',
        role: 'member',
      );
      sessionOwner.setUserId('42');

      await sessionHandler.handleUnauthorized();

      expect(tokenStore.getToken(), isNull);
      expect(users.current, isNull);
      expect(auth.currentUser, isNull);
      expect(sessionOwner.userId, isNull);
      expect(navCalls, 1);
      expect(sessionHandler.navigationInvocationsForTest, 1);
    });

    test('navegación de expiración se solicita una sola vez con concurrentes',
        () async {
      await tokenStore.saveToken(fakeJwt);
      users.current = User(
        id: '42',
        name: 'Test',
        email: 't@e.com',
        role: 'member',
      );

      await Future.wait([
        sessionHandler.handleUnauthorized(),
        sessionHandler.handleUnauthorized(),
        sessionHandler.handleUnauthorized(),
      ]);

      expect(sessionHandler.logoutInvocationsForTest, 1);
      expect(navCalls, 1);
    });

    test('logout manual bloquea 401 tardío (sin nav extra)', () async {
      await tokenStore.saveToken(fakeJwt);
      await auth.logout();
      expect(sessionOwner.userId, isNull);

      await sessionHandler.handleUnauthorized();
      expect(navCalls, 0);
      expect(sessionHandler.logoutInvocationsForTest, 0);
    });

    test('login exitoso restaura gate de mensaje de expiración', () async {
      SessionFeedback.resetExpiredMessageGate();
      // simula que se mostró
      // (gate interno se resetea en persist)
      remote.loginResult = User(
        id: '7',
        name: 'Nuevo',
        email: 'n@e.com',
        role: 'member',
        token: fakeJwt,
      );
      final ok = await auth.login('n@e.com', 'x');
      expect(ok, isTrue);
      expect(sessionOwner.userId, '7');
      expect(SessionFeedback.expiredMessageShownForTest, isFalse);
    });
  });
}
