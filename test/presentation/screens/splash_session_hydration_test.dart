import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_user_repository.dart';
import '../../core/auth/in_memory_secure_storage_gateway.dart';

class _ConfigurableAuthRemote implements AuthRemoteDataSource {
  Object? getMeError;

  @override
  Future<bool> checkEmailExists(String email) async => false;

  @override
  Future<User> getMe() async {
    if (getMeError != null) throw getMeError!;
    return User(
      id: '30',
      name: 'Socio Remoto',
      email: 'socio@test.com',
      role: 'member',
    );
  }

  @override
  Future<User> login(String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<User> loginWithGoogle(String idToken) async =>
      throw UnimplementedError();

  @override
  Future<User> register(
    String nombre,
    String apellido,
    String email,
    String password,
    String telefono, {
    int? rolId,
  }) async =>
      throw UnimplementedError();

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

class _FailingGetUserRepository extends FakeUserRepository {
  @override
  Future<User?> getUser(String id) async => null;
}

User _memberProfile({String id = '30'}) => User(
      id: id,
      name: 'Socio Local',
      email: 'socio@test.com',
      role: 'member',
    );

Future<AuthProvider> _authWithStoredSession({
  required FakeUserRepository users,
  required SecureTokenStore tokenStore,
  AuthRemoteDataSource? remote,
  User? profile,
}) async {
  final member = profile ?? _memberProfile();
  users.current = member.withoutToken();
  await tokenStore.saveToken('fake.jwt.token.value');

  return AuthProvider(
    remote ?? _ConfigurableAuthRemote(),
    users,
    tokenStore,
    sessionMigrator: SessionTokenMigrator(
      tokenStore: tokenStore,
      userRepository: users,
    ),
  );
}

GoRouter _routerForRole(String expectedBody) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login')),
      ),
      GoRoute(
        path: '/member-home',
        builder: (_, __) => Scaffold(body: Text(expectedBody)),
      ),
      GoRoute(
        path: '/host-dashboard',
        builder: (_, __) => const Scaffold(body: Text('Host Dashboard')),
      ),
      GoRoute(
        path: '/basic-home',
        builder: (_, __) => const Scaffold(body: Text('Basic Home')),
      ),
    ],
  );
}

Future<void> _pumpUntilText(WidgetTester tester, String text) async {
  await tester.pump(const Duration(seconds: 3));
  for (var i = 0; i < 50; i++) {
    if (find.text(text).evaluate().isNotEmpty) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  group('hydrateUserProviderAfterBootstrap', () {
    test('loadUser desde SQLite no incluye JWT', () async {
      final users = FakeUserRepository()
        ..current = _memberProfile().withoutToken();
      final userProvider = UserProvider(users);
      final authUser = _memberProfile().copyWith(token: 'secret.jwt');

      await hydrateUserProviderAfterBootstrap(userProvider, authUser);

      expect(userProvider.currentUser, isNotNull);
      expect(userProvider.currentUser!.id, '30');
      expect(userProvider.currentUser!.token, isNull);
    });

    test('fallback setUser sin token si SQLite no responde', () async {
      final users = _FailingGetUserRepository();
      final userProvider = UserProvider(users);
      final authUser = _memberProfile().copyWith(token: 'secret.jwt');

      await hydrateUserProviderAfterBootstrap(userProvider, authUser);

      expect(userProvider.currentUser, isNotNull);
      expect(userProvider.currentUser!.token, isNull);
    });
  });

  group('SESSION-001 cold start bootstrap + UserProvider', () {
    late InMemorySecureStorageGateway storage;
    late SecureTokenStore tokenStore;

    setUp(() async {
      storage = InMemorySecureStorageGateway();
      tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
    });

    test('SOCIO: bootstrapSession + hidratación dejan UserProvider listo',
        () async {
      final users = FakeUserRepository();
      final auth = await _authWithStoredSession(
        users: users,
        tokenStore: tokenStore,
      );
      final userProvider = UserProvider(users);

      final session = await auth.bootstrapSession();
      expect(session, isNotNull);
      expect(session!.role, 'member');

      await hydrateUserProviderAfterBootstrap(userProvider, session);

      expect(userProvider.currentUser, isNotNull);
      expect(userProvider.currentUser!.id, '30');
      expect(userProvider.currentUser!.token, isNull);
      expect(users.saveUserCalls, 0);
    });

    test('getMe con error de red conserva sesión y permite hidratar local',
        () async {
      final users = FakeUserRepository();
      final remote = _ConfigurableAuthRemote()
        ..getMeError = NetworkException('Sin conexión');
      final auth = await _authWithStoredSession(
        users: users,
        tokenStore: tokenStore,
        remote: remote,
      );
      final userProvider = UserProvider(users);

      final session = await auth.bootstrapSession();
      expect(session, isNotNull);
      expect(auth.currentUser, isNotNull);

      await hydrateUserProviderAfterBootstrap(userProvider, session!);

      expect(userProvider.currentUser?.id, '30');
      expect(userProvider.currentUser?.token, isNull);
    });

    test('ADMIN legacy: bootstrap guest no hidrata UserProvider', () async {
      final users = FakeUserRepository();
      final remote = _ConfigurableAuthRemote()
        ..getMeError = AdminMobileNotSupportedException();
      final auth = await _authWithStoredSession(
        users: users,
        tokenStore: tokenStore,
        remote: remote,
        profile: User(
          id: '30',
          name: 'Legacy Admin',
          email: 'admin@test.com',
          role: 'host',
        ),
      );
      final userProvider = UserProvider(users);

      final session = await auth.bootstrapSession();
      expect(session, isNull);
      expect(auth.currentUser, isNull);
      expect(tokenStore.getToken(), isNull);
      expect(users.current, isNull);

      // Splash no debe llamar hidratación cuando user == null.
      expect(userProvider.currentUser, isNull);
    });

    testWidgets('SOCIO splash hidrata UserProvider antes de /member-home',
        (tester) async {
      final users = FakeUserRepository()
        ..current = _memberProfile().withoutToken();
      await tokenStore.saveToken('fake.jwt.token.value');

      late UserProvider userProvider;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider(
                _ConfigurableAuthRemote(),
                users,
                tokenStore,
                sessionMigrator: SessionTokenMigrator(
                  tokenStore: tokenStore,
                  userRepository: users,
                ),
              ),
            ),
            ChangeNotifierProvider(
              create: (context) {
                userProvider = UserProvider(users);
                return userProvider;
              },
            ),
          ],
          child: MaterialApp.router(
            routerConfig: _routerForRole('Member Home'),
          ),
        ),
      );

      await _pumpUntilText(tester, 'Member Home');

      expect(userProvider.currentUser, isNotNull);
      expect(userProvider.currentUser!.role, 'member');
      expect(userProvider.currentUser!.token, isNull);
      expect(find.text('Member Home'), findsOneWidget);
    });

    testWidgets('ANFITRION splash hidrata y navega a /host-dashboard',
        (tester) async {
      final users = FakeUserRepository()
        ..current = User(
          id: '7',
          name: 'Host Local',
          email: 'host@test.com',
          role: 'host',
        );
      await tokenStore.saveToken('fake.jwt.token.value');

      late UserProvider userProvider;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider(
                _ConfigurableAuthRemote(),
                users,
                tokenStore,
                sessionMigrator: SessionTokenMigrator(
                  tokenStore: tokenStore,
                  userRepository: users,
                ),
              ),
            ),
            ChangeNotifierProvider(
              create: (context) {
                userProvider = UserProvider(users);
                return userProvider;
              },
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
                GoRoute(
                  path: '/host-dashboard',
                  builder: (_, __) =>
                      const Scaffold(body: Text('Host Dashboard')),
                ),
              ],
            ),
          ),
        ),
      );

      await _pumpUntilText(tester, 'Host Dashboard');

      expect(userProvider.currentUser?.role, 'host');
      expect(userProvider.currentUser?.token, isNull);
    });

    testWidgets('USUARIO_BASICO splash hidrata y navega a /basic-home',
        (tester) async {
      final users = FakeUserRepository()
        ..current = User(
          id: '9',
          name: 'Basico Local',
          email: 'basic@test.com',
          role: 'basic_user',
        );
      await tokenStore.saveToken('fake.jwt.token.value');

      late UserProvider userProvider;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider(
                _ConfigurableAuthRemote(),
                users,
                tokenStore,
                sessionMigrator: SessionTokenMigrator(
                  tokenStore: tokenStore,
                  userRepository: users,
                ),
              ),
            ),
            ChangeNotifierProvider(
              create: (context) {
                userProvider = UserProvider(users);
                return userProvider;
              },
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
                GoRoute(
                  path: '/basic-home',
                  builder: (_, __) => const Scaffold(body: Text('Basic Home')),
                ),
              ],
            ),
          ),
        ),
      );

      await _pumpUntilText(tester, 'Basic Home');

      expect(userProvider.currentUser?.role, 'basic_user');
      expect(userProvider.currentUser?.token, isNull);
    });
  });
}
