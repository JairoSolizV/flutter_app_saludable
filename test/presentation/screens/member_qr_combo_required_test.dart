import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/domain/entities/club_membership.dart';
import 'package:flutter_app_saludable/presentation/screens/member/qrcode/member_qr_scan_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

ClubMembership _membership({
  int clubId = 7,
  String clubNombre = 'Club Membresía',
}) {
  return ClubMembership(
    id: 11,
    usuarioId: 22,
    usuarioNombre: 'Ana',
    clubId: clubId,
    clubNombre: clubNombre,
    nivelId: 1,
    nivelNombre: 'Socio',
    numeroSocio: 'SC-001',
    puntosAcumulados: 0,
    fechaRegistro: '2026-01-01',
    estado: 'ACTIVA',
  );
}

void main() {
  group('comboRequiredOrderExtra', () {
    test('usa clubId y clubNombre de la membresía, no del QR', () {
      final membership = _membership(clubId: 7, clubNombre: 'Club Norte');

      final extra = comboRequiredOrderExtra(membership);

      expect(extra['clubId'], 7);
      expect(extra['clubNombre'], 'Club Norte');
      expect(extra['clubId'], isNot(99));
    });
  });

  group('ComboRequiredAttendanceDialog', () {
    testWidgets('ofrece Entendido y Hacer pedido', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ComboRequiredAttendanceDialog(),
        ),
      );

      expect(
        find.text(ComboRequiredAttendanceDialog.body),
        findsOneWidget,
      );
      expect(find.text('Entendido'), findsOneWidget);
      expect(find.text('Hacer pedido'), findsOneWidget);
      expect(find.textContaining('¡Asistencia Registrada!'), findsNothing);
    });

    testWidgets('Entendido cierra el diálogo sin navegar', (tester) async {
      Map<String, dynamic>? capturedExtra;

      final router = GoRouter(
        initialLocation: '/scan',
        routes: [
          GoRoute(
            path: '/scan',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => handleComboRequiredAttendance(
                  context: context,
                  membership: _membership(),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
          GoRoute(
            path: '/member-orders',
            builder: (_, __) => const SizedBox.shrink(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const SizedBox.shrink(),
                routes: [
                  GoRoute(
                    path: 'club-products',
                    builder: (context, state) {
                      capturedExtra = Map<String, dynamic>.from(
                        state.extra as Map,
                      );
                      return const Scaffold(body: Text('catálogo'));
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Hacer pedido'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      expect(find.text('Hacer pedido'), findsNothing);
      expect(find.text('catálogo'), findsNothing);
      expect(capturedExtra, isNull);
    });
  });

  group('handleComboRequiredAttendance CTA', () {
    testWidgets(
        'Hacer pedido navega al catálogo del club de la membresía',
        (tester) async {
      Map<String, dynamic>? capturedExtra;

      final membership = _membership(clubId: 7, clubNombre: 'Club Norte');
      final router = GoRouter(
        initialLocation: '/scan',
        routes: [
          GoRoute(
            path: '/scan',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => handleComboRequiredAttendance(
                  context: context,
                  membership: membership,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
          GoRoute(
            path: '/member-orders',
            builder: (_, __) => const SizedBox.shrink(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const Scaffold(body: Text('selector clubes')),
                routes: [
                  GoRoute(
                    path: 'club-products',
                    builder: (context, state) {
                      capturedExtra = Map<String, dynamic>.from(
                        state.extra as Map,
                      );
                      return const Scaffold(body: Text('catálogo'));
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hacer pedido'));
      await tester.pumpAndSettle();

      expect(find.text('catálogo'), findsOneWidget);
      expect(find.text('selector clubes'), findsNothing);
      expect(capturedExtra, isNotNull);
      expect(capturedExtra!['clubId'], membership.clubId);
      expect(capturedExtra!['clubNombre'], membership.clubNombre);
    });
  });
}
