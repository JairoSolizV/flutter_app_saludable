import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/presentation/screens/member/basic_user_main_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _buildApp() {
  final router = GoRouter(
    initialLocation: '/basic-home',
    routes: [
      ShellRoute(
        builder: (_, __, child) => BasicUserMainScreen(child: child),
        routes: [
          GoRoute(
            path: '/basic-home',
            builder: (_, __) => const Scaffold(body: Text('Home Básico')),
          ),
          GoRoute(
            path: '/basic-profile',
            builder: (_, __) => const Scaffold(body: Text('Perfil Básico')),
          ),
        ],
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('expone exactamente dos tabs: Inicio y Perfil', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final navBar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );

    expect(navBar.items.length, 2);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('no expone el tab de Mapa', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Mapa'), findsNothing);
  });

  testWidgets('el tab Perfil navega a /basic-profile', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Perfil Básico'), findsOneWidget);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );
  });

  testWidgets('el tab Inicio vuelve a /basic-home', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    expect(find.text('Home Básico'), findsOneWidget);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      0,
    );
  });
}
