import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/data/datasources/remote/membresia_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/qr_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/presentation/providers/auth_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/user_provider.dart';
import 'package:flutter_app_saludable/presentation/screens/member/member_profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/fake_google_auth_service.dart';
import '../../core/auth/fake_user_repository.dart';
import '../../core/auth/in_memory_secure_storage_gateway.dart';

class _StubAuthRemote implements AuthRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQrRemoteDataSource implements QRRemoteDataSource {
  @override
  Future<QrResponse> getSocioQR() async => QrResponse(
        qrPayload: 'SOCIO:TEST-001',
        tipo: 'SOCIO',
        numeroSocio: 'TEST-001',
        clubId: 3,
        clubNombre: 'Club prueba',
      );

  @override
  Future<QRValidacionResponse> validarSocioQR(String qr, int clubId) =>
      throw UnimplementedError();
}

class _FakeMembresiaRemoteDataSource implements MembresiaRemoteDataSource {
  @override
  Future<List<ClubMembership>> getMembresiasPorUsuario(int usuarioId) async =>
      [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildProfileApp({
  required UserProvider userProvider,
  required AuthProvider authProvider,
  required GoRouter router,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      Provider<QRRemoteDataSource>.value(value: _FakeQrRemoteDataSource()),
      Provider<MembresiaRemoteDataSource>.value(
        value: _FakeMembresiaRemoteDataSource(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<AuthProvider> _authWithToken(FakeUserRepository users) async {
  final storage = InMemorySecureStorageGateway();
  final tokenStore = SecureTokenStore(storage: storage);
  await tokenStore.initialize();
  await tokenStore.saveToken('fake.jwt.token.value');
  return AuthProvider(
    _StubAuthRemote(),
    users,
    tokenStore,
    googleAuthService: FakeGoogleAuthService(),
  );
}

void main() {
  group('MemberProfileScreen SESSION-001', () {
    testWidgets('con UserProvider hidratado muestra perfil y logout',
        (tester) async {
      final users = FakeUserRepository();
      final userProvider = UserProvider(users)
        ..setUser(User(
          id: '30',
          name: 'Socio Local',
          email: 'socio@test.com',
          role: 'member',
          phone: '555',
        ));
      final authProvider = await _authWithToken(users);

      final router = GoRouter(
        initialLocation: '/member-profile',
        routes: [
          GoRoute(
            path: '/member-profile',
            builder: (_, __) => const MemberProfileScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildProfileApp(
          userProvider: userProvider,
          authProvider: authProvider,
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Error: Usuario no encontrado'), findsNothing);
      expect(find.text('Socio Local'), findsOneWidget);
      expect(find.text('Cerrar Sesión'), findsOneWidget);
    });

    testWidgets('fallback sin UserProvider permite cerrar sesión', (tester) async {
      final users = FakeUserRepository()
        ..current = User(
          id: '30',
          name: 'Socio Local',
          email: 'socio@test.com',
          role: 'member',
        );
      final userProvider = UserProvider(users);
      final authProvider = await _authWithToken(users);
      var guestReached = false;

      final router = GoRouter(
        initialLocation: '/member-profile',
        routes: [
          GoRoute(
            path: '/member-profile',
            builder: (_, __) => const MemberProfileScreen(),
          ),
          GoRoute(
            path: '/guest-home',
            builder: (_, __) {
              guestReached = true;
              return const Scaffold(body: Text('Guest Home'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        _buildProfileApp(
          userProvider: userProvider,
          authProvider: authProvider,
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Error: Usuario no encontrado'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(guestReached, isTrue);
      expect(users.current, isNull);
      expect(userProvider.currentUser, isNull);
    });
  });
}
