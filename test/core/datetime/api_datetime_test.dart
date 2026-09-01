import 'package:flutter_app_saludable/core/datetime/api_datetime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseApiDateTimeToLocal', () {
    test('null retorna null', () {
      expect(parseApiDateTimeToLocal(null), isNull);
    });

    test('string inválido retorna null', () {
      expect(parseApiDateTimeToLocal('no-es-fecha'), isNull);
      expect(parseApiDateTimeToLocal(''), isNull);
    });

    test('timestamp con Z se convierte a local', () {
      final local = parseApiDateTimeToLocal('2026-08-31T19:00:00Z');
      expect(local, isNotNull);
      expect(local!.isUtc, isFalse);
      expect(local.toUtc(), DateTime.utc(2026, 8, 31, 19, 0));
    });

    test('timestamp con +00:00 se convierte a local', () {
      final local = parseApiDateTimeToLocal('2026-08-31T19:00:00+00:00');
      expect(local, isNotNull);
      expect(local!.toUtc(), DateTime.utc(2026, 8, 31, 19, 0));
    });

    test('timestamp con offset diferente se respeta', () {
      final local = parseApiDateTimeToLocal('2026-08-31T21:00:00+02:00');
      expect(local, isNotNull);
      expect(local!.toUtc(), DateTime.utc(2026, 8, 31, 19, 0));
    });

    test('no aplica aritmética manual de horas', () {
      final source = '2026-08-31T19:00:00Z';
      final parsed = parseApiDateTimeToLocal(source);
      expect(parsed, isNotNull);
      expect(
        parsed!.difference(DateTime.parse(source).toLocal()).inSeconds,
        0,
      );
    });
  });
}
