import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_app_saludable/presentation/widgets/club_card.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Club _club({
  String direccion = 'Av. Siempre Viva 123',
  String horario = '08:00-18:00',
}) {
  return Club(
    id: 1,
    hubId: 1,
    hubNombre: 'Hub 1',
    anfitrionId: 2,
    anfitrionNombre: 'Ana',
    nombreClub: 'Club de Prueba',
    direccion: direccion,
    horario: horario,
    lat: -17.7,
    lng: -63.1,
    estado: 'ACTIVO',
  );
}

void main() {
  group('ClubCard', () {
    testWidgets('renderiza nombre, dirección y horario', (tester) async {
      await tester.pumpWidget(_wrap(ClubCard(club: _club(), onTap: () {})));
      await tester.pump();

      expect(find.text('Club de Prueba'), findsOneWidget);
      expect(find.text('Av. Siempre Viva 123'), findsOneWidget);
      expect(find.text('08:00-18:00'), findsOneWidget);
      expect(find.text('ORDENAR'), findsOneWidget);
    });

    testWidgets('sin horario no muestra la fila de horario', (tester) async {
      await tester.pumpWidget(
          _wrap(ClubCard(club: _club(horario: ''), onTap: () {})));
      await tester.pump();

      expect(find.text('08:00-18:00'), findsNothing);
    });

    testWidgets('con distancia la muestra formateada', (tester) async {
      await tester.pumpWidget(
          _wrap(ClubCard(club: _club(), onTap: () {}, distance: 3.456)));
      await tester.pump();

      expect(find.text('3.5 km'), findsOneWidget);
    });

    testWidgets('onTap se invoca al tocar la tarjeta', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
          _wrap(ClubCard(club: _club(), onTap: () => tapped = true)));

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
