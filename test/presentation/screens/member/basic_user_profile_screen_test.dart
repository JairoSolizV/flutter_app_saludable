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
  });
}
