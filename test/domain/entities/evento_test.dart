import 'package:flutter_app_saludable/domain/entities/evento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Evento.parseFechaEventoValue', () {
    test('YYYY-MM-DD conserva día local sin desplazamiento UTC', () {
      final parsed = Evento.parseFechaEventoValue('2026-08-31');
      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 8);
      expect(parsed.day, 31);
    });

    test('null retorna null', () {
      expect(Evento.parseFechaEventoValue(null), isNull);
    });

    test('vacío retorna null', () {
      expect(Evento.parseFechaEventoValue(''), isNull);
    });

    test('inválido retorna null', () {
      expect(Evento.parseFechaEventoValue('no-es-fecha'), isNull);
    });
  });

  group('Evento.filterUpcoming', () {
    Evento event({
      required int id,
      required DateTime fecha,
    }) {
      return Evento(
        id: id,
        nombre: 'Evento $id',
        fechaEvento: fecha,
        descripcion: '',
      );
    }

    test('excluye ayer, incluye hoy y mañana', () {
      final reference = DateTime(2026, 8, 31, 18, 30);
      final ayer = DateTime(2026, 8, 30);
      final hoy = DateTime(2026, 8, 31);
      final manana = DateTime(2026, 9, 1);

      final filtered = Evento.filterUpcoming(
        [
          event(id: 1, fecha: ayer),
          event(id: 2, fecha: hoy),
          event(id: 3, fecha: manana),
        ],
        reference,
      );

      expect(filtered.map((e) => e.id).toList(), [2, 3]);
    });

    test('ordena ascendente hoy, mañana, futuro', () {
      final reference = DateTime(2026, 8, 31, 10);
      final filtered = Evento.filterUpcoming(
        [
          event(id: 3, fecha: DateTime(2026, 9, 10)),
          event(id: 1, fecha: DateTime(2026, 8, 31)),
          event(id: 2, fecha: DateTime(2026, 9, 1)),
        ],
        reference,
      );

      expect(filtered.map((e) => e.id).toList(), [1, 2, 3]);
    });
  });

  group('Evento.fromJson', () {
    test('fecha inválida lanza FormatException', () {
      expect(
        () => Evento.fromJson({
          'id': 1,
          'nombre': 'X',
          'fechaEvento': 'invalida',
          'descripcion': '',
        }),
        throwsFormatException,
      );
    });

    test('fecha null lanza FormatException', () {
      expect(
        () => Evento.fromJson({
          'id': 1,
          'nombre': 'X',
          'descripcion': '',
        }),
        throwsFormatException,
      );
    });
  });
}
