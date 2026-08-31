import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/presentation/screens/member/member_select_club_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class _StubClubDs extends ClubRemoteDataSource {
  _StubClubDs() : super(Dio());

  @override
  Future<List<Club>> getClubes() async => [];
}

/// Réplica mínima del tramo relevante de [appRouter] para evitar el splash
/// global (`initialLocation: '/'`) y sus timers en tests.
GoRouter _memberOrdersRouter({String initialLocation = '/member-orders/legacy'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/member-orders',
            builder: (context, state) =>
                const Scaffold(body: Text('Lista pedidos')),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const MemberSelectClubScreen(),
              ),
              GoRoute(
                path: 'legacy',
                redirect: (context, state) => '/member-orders/new',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '/member-orders/legacy redirige al flujo canónico /member-orders/new',
    (tester) async {
      final router = _memberOrdersRouter();

      await tester.pumpWidget(
        Provider<ClubRemoteDataSource>.value(
          value: _StubClubDs(),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MemberSelectClubScreen), findsOneWidget);
      expect(find.text('Seleccionar Club'), findsOneWidget);

      final location = GoRouterState.of(
        tester.element(find.byType(MemberSelectClubScreen)),
      ).uri.toString();
      expect(location, '/member-orders/new');
    },
  );
}
