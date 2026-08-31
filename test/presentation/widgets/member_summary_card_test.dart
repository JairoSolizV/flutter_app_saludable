import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/presentation/widgets/member_summary_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemberSummaryCard', () {
    testWidgets('muestra Mi membresía y datos reales', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MemberSummaryCard(
              clubName: 'Club prueba',
              memberNumber: 'CV-00000123',
              points: 120,
              attendanceCount: 8,
              membershipLevel: 'Oro',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mi membresía'), findsOneWidget);
      expect(find.text('Club prueba'), findsOneWidget);
      expect(find.text('120 pts'), findsOneWidget);
      expect(find.text('Puntos acumulados'), findsOneWidget);
      expect(find.text('8 asistencias'), findsOneWidget);
      expect(find.text('CV-00000123'), findsOneWidget);
      expect(find.text('Nivel: Oro'), findsOneWidget);
    });

    testWidgets('no muestra terminología de fidelidad', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MemberSummaryCard(
              clubName: 'Club',
              memberNumber: 'CL-000003',
              points: 0,
              attendanceCount: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tarjeta de Fidelidad'), findsNothing);
      expect(find.textContaining('Sellos'), findsNothing);
      expect(find.textContaining('Recompensa'), findsNothing);
      expect(find.textContaining('meta'), findsNothing);
    });

    testWidgets('muestra código histórico sin modificar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MemberSummaryCard(
              clubName: 'Club',
              memberNumber: 'CL-000003',
              points: 10,
              attendanceCount: 1,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CL-000003'), findsOneWidget);
      expect(find.text('1 asistencia'), findsOneWidget);
    });

    testWidgets('12 asistencias muestra 12, no módulo 10', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MemberSummaryCard(
              clubName: 'Club',
              memberNumber: 'CV-00000123',
              points: 50,
              attendanceCount: 12,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('12 asistencias'), findsOneWidget);
      expect(find.text('2 asistencias'), findsNothing);
    });

    testWidgets('sin numeroSocio muestra No disponible', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MemberSummaryCard(
              clubName: 'Club',
              memberNumber: '',
              points: 0,
              attendanceCount: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No disponible'), findsWidgets);
    });

    testWidgets('attendanceCount null muestra No disponible', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MemberSummaryCard(
              clubName: 'Club',
              memberNumber: 'CV-1',
              points: 5,
              attendanceCount: null,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No disponible'), findsOneWidget);
    });

    group('formatters', () {
      test('formatMemberNumber vacío', () {
        expect(MemberSummaryCard.formatMemberNumber(''), 'No disponible');
      });

      test('formatAttendanceValue pluralización', () {
        expect(MemberSummaryCard.formatAttendanceValue(null), 'No disponible');
        expect(MemberSummaryCard.formatAttendanceValue(0), '0 asistencias');
        expect(MemberSummaryCard.formatAttendanceValue(1), '1 asistencia');
        expect(MemberSummaryCard.formatAttendanceValue(8), '8 asistencias');
      });
    });
  });
}
