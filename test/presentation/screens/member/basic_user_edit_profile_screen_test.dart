import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/member/basic_user_edit_profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/fake_google_auth_service.dart';
import '../../../core/auth/fake_user_repository.dart';
import '../../../core/auth/in_memory_secure_storage_gateway.dart';

final _user = User(
  id: '42',
  name: 'Ana Pérez',
  email: 'ana@example.com',
  role: 'basic_user',
  phone: '+59173429001',
  token: 'jwt-test',
);

class _TrackingAuthRemote implements AuthRemoteDataSource {
  int updateUserCalls = 0;
  User? lastUpdatedUser;

  @override
  Future<User> updateUser(User user) async {
    updateUserCalls++;
    lastUpdatedUser = user;
    return user.copyWith(clearToken: true);
  }

  @override
  Future<User> getMe() async => _user;

  @override
  Future<User> login(String email, String password) async => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpEditProfile(
  WidgetTester tester, {
  required FakeUserRepository users,
  required AuthProvider auth,
  required UserProvider userProvider,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const BasicUserEditProfileScreen(),
            ),
            GoRoute(
              path: '/basic-home',
              builder: (_, __) => const Scaffold(body: Text('Home')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<(AuthProvider, _TrackingAuthRemote, UserProvider)> _buildAuthed(
  FakeUserRepository users,
) async {
  final storage = InMemorySecureStorageGateway();
  final tokenStore = SecureTokenStore(storage: storage);
  await tokenStore.initialize();
  final remote = _TrackingAuthRemote();
  final auth = AuthProvider(
    remote,
    users,
    tokenStore,
    googleAuthService: FakeGoogleAuthService(),
  );
  // Hidratar sesión autenticada (AuthProvider.updateProfile exige currentUser).
  await auth.login('ana@example.com', 'secretpw');
  final userProvider = UserProvider(users)..setUser(auth.currentUser ?? _user);
  return (auth, remote, userProvider);
}

void main() {
  group('BasicUserEditProfileScreen PROFILE-SOCIAL-FL-001', () {
    testWidgets('Facebook permite espacios mientras escribe', (tester) async {
      final users = FakeUserRepository();
      final (auth, _, userProvider) = await _buildAuthed(users);
      await _pumpEditProfile(
        tester,
        users: users,
        auth: auth,
        userProvider: userProvider,
      );

      final facebookField = find.byType(TextFormField).at(5);
      await tester.enterText(facebookField, 'Mi Pagina Oficial');
      await tester.pump();

      expect(find.text('Mi Pagina Oficial'), findsOneWidget);
    });
  });

  group('BasicUserEditProfileScreen BASIC-PROFILE-PHONE-FL-001', () {
    testWidgets('teléfono +591 existente se muestra sin prefijo y es válido',
        (tester) async {
      final users = FakeUserRepository();
      final (auth, _, userProvider) = await _buildAuthed(users);
      await _pumpEditProfile(
        tester,
        users: users,
        auth: auth,
        userProvider: userProvider,
      );

      final phoneField = find.byType(TextFormField).at(2);
      final field = tester.widget<TextFormField>(phoneField);
      expect(field.controller?.text, '73429001');
      expect(field.validator?.call('73429001'), isNull);
    });

    testWidgets('guardar llama AuthProvider.updateProfile (remoto)',
        (tester) async {
      final users = FakeUserRepository();
      final (auth, remote, userProvider) = await _buildAuthed(users);
      await _pumpEditProfile(
        tester,
        users: users,
        auth: auth,
        userProvider: userProvider,
      );

      final nameField = find.byType(TextFormField).at(0);
      await tester.enterText(nameField, 'Ana María Pérez');
      await tester.pump();

      final saveButton = find.text('Guardar Cambios');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(remote.updateUserCalls, 1);
      expect(remote.lastUpdatedUser?.name, 'Ana María Pérez');
      expect(remote.lastUpdatedUser?.phone, '+59173429001');
      expect(auth.currentUser?.name, 'Ana María Pérez');
      expect(userProvider.currentUser?.name, 'Ana María Pérez');
      expect(find.textContaining('8 dígitos'), findsNothing);
    });
  });
}
