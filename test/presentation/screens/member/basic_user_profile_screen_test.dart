import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/member/basic_user_profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/fake_google_auth_service.dart';
import '../../../core/auth/fake_user_repository.dart';
import '../../../core/auth/in_memory_secure_storage_gateway.dart';

class _StubAuthRemote implements AuthRemoteDataSource {
  final User user;

  _StubAuthRemote(this.user);

  @override
  Future<User> getMe() async => user;


  @override
  Future<void> deleteAccount() async => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<AuthProvider> _authProvider(FakeUserRepository users, User user) async {
  final storage = InMemorySecureStorageGateway();
  final tokenStore = SecureTokenStore(storage: storage);
  await tokenStore.initialize();
  return AuthProvider(
    _StubAuthRemote(user),
    users,
    tokenStore,
    googleAuthService: FakeGoogleAuthService(),
  );
}

void main() {
  testWidgets('USUARIO_BASICO no muestra menú de tres puntos inútil',
      (tester) async {
    final users = FakeUserRepository();
    final user = User(
      id: '42',
      name: 'Ana Pérez',
      email: 'ana@example.com',
      role: 'basic_user',
      phone: '+59173429001',
    );
    final userProvider = UserProvider(users)..setUser(user);
    final authProvider = await _authProvider(users, user);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const BasicUserProfileScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.text('Editar mis datos'), findsOneWidget);
    expect(find.text('Eliminar cuenta'), findsOneWidget);
  });

  testWidgets('cancelar Eliminar cuenta no llama API', (tester) async {
    final users = FakeUserRepository();
    final user = User(
      id: '42',
      name: 'Ana Pérez',
      email: 'ana@example.com',
      role: 'basic_user',
      phone: '+59173429001',
    );
    final userProvider = UserProvider(users)..setUser(user);
    final remote = _TrackingDeleteRemote(user);
    final storage = InMemorySecureStorageGateway();
    final tokenStore = SecureTokenStore(storage: storage);
    await tokenStore.initialize();
    await tokenStore.saveToken('jwt');
    final authProvider = AuthProvider(
      remote,
      users,
      tokenStore,
      googleAuthService: FakeGoogleAuthService(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const BasicUserProfileScreen(),
              ),
              GoRoute(
                path: '/login',
                builder: (_, __) => const Scaffold(body: Text('Login')),
              ),
              GoRoute(
                path: '/basic-profile/edit',
                builder: (_, __) => const Scaffold(body: Text('Edit')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eliminar cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Esta acción eliminará tu cuenta y cerrará tu sesión. Algunos datos operativos pueden conservarse anonimizados cuando sea necesario.'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(remote.deleteCalls, 0);
    expect(tokenStore.getToken(), 'jwt');
  });
}

class _TrackingDeleteRemote implements AuthRemoteDataSource {
  _TrackingDeleteRemote(this.user);
  final User user;
  int deleteCalls = 0;

  @override
  Future<User> getMe() async => user;

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
