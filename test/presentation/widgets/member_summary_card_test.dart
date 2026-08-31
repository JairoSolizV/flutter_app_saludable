import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/presentation/widgets/member_summary_card.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {double textScale = 1.0, double width = 390}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SizedBox(width: width - 32, child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('MemberSummaryCard', () {
    testWidgets('muestra Mi membresía y datos reales', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MemberSummaryCard(
            clubName: 'Club prueba',
            memberNumber: 'CV-00000123',
            points: 120,
            attendanceCount: 8,
            membershipLevel: 'Oro',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mi membresía'), findsOneWidget);
      expect(find.text('Club prueba'), findsOneWidget);
      expect(find.text('120 pts'), findsOneWidget);
      expect(find.text('Puntos acumulados'), findsOneWidget);
      expect(find.text('8 asistencias'), findsOneWidget);
      expect(find.text('Asistencias registradas'), findsOneWidget);
      expect(find.text('N.º de socio'), findsOneWidget);
      expect(find.text('CV-00000123'), findsOneWidget);
      expect(find.text('Nivel: Oro'), findsOneWidget);
    });

    testWidgets('no muestra terminología de fidelidad', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MemberSummaryCard(
            clubName: 'Club',
            memberNumber: 'CL-000003',
            points: 0,
            attendanceCount: 0,
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
        _wrap(
          const MemberSummaryCard(
            clubName: 'Club',
            memberNumber: 'CL-000003',
            points: 10,
            attendanceCount: 1,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CL-000003'), findsOneWidget);
      expect(find.text('1 asistencia'), findsOneWidget);
    });

    testWidgets('12 asistencias muestra 12, no módulo 10', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MemberSummaryCard(
            clubName: 'Club',
            memberNumber: 'CV-00000123',
            points: 50,
            attendanceCount: 12,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('12 asistencias'), findsOneWidget);
      expect(find.text('2 asistencias'), findsNothing);
    });

    testWidgets('sin numeroSocio muestra No disponible', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MemberSummaryCard(
            clubName: 'Club',
            memberNumber: '',
            points: 0,
            attendanceCount: 0,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No disponible'), findsWidgets);
    });

    testWidgets('attendanceCount null muestra No disponible', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MemberSummaryCard(
            clubName: 'Club',
            memberNumber: 'CV-1',
            points: 5,
            attendanceCount: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No disponible'), findsOneWidget);
    });

    testWidgets('membershipLevel null no muestra Nivel', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MemberSummaryCard(
            clubName: 'Club',
            memberNumber: 'CV-1',
            points: 5,
            attendanceCount: 0,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Nivel:'), findsNothing);
    });

    testWidgets('nombre de club largo no produce overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MemberSummaryCard(
            clubName:
                'Club Deportivo Norte Saludable y Comunitario de Formación Integral',
            memberNumber: 'CN-00000007',
            points: 10,
            attendanceCount: 3,
            membershipLevel: 'Socio',
          ),
          width: 320,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Club Deportivo Norte'), findsOneWidget);
    });

    testWidgets('memberNumber largo no produce overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MemberSummaryCard(
            clubName: 'Club Norte',
            memberNumber: 'CLUB-NORTE-HISTORICO-000000000000123456789',
            points: 99999,
            attendanceCount: 120,
          ),
          width: 300,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('CLUB-NORTE-HISTORICO-000000000000123456789'),
        findsOneWidget,
      );
    });

    testWidgets('textScaleFactor elevado no produce excepción de layout',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MemberSummaryCard(
            clubName: 'Club con nombre bastante largo para probar escala',
            memberNumber: 'CN-00000007',
            points: 10,
            attendanceCount: 0,
            membershipLevel: 'Nivel Preferencial Extendido',
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Mi membresía'), findsOneWidget);
    });

    test('conserva parámetros públicos del constructor', () {
      const card = MemberSummaryCard(
        clubName: 'A',
        memberNumber: 'B',
        points: 1,
        attendanceCount: 2,
        membershipLevel: 'C',
      );
      expect(card.clubName, 'A');
      expect(card.memberNumber, 'B');
      expect(card.points, 1);
      expect(card.attendanceCount, 2);
      expect(card.membershipLevel, 'C');
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
