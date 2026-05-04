import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app_saludable/domain/entities/compra_manual.dart';

void main() {
  group('CompraManual', () {
    test('fromJson parsea campos correctamente', () {
      final json = {
        'id': 1,
        'membresiaId': 12,
        'clubId': 5,
        'descripcion': '2 batidos proteína',
        'monto': 35.5,
        'fecha': '2026-05-03',
        'registradaPorHostId': 3,
      };
      final c = CompraManual.fromJson(json);
      expect(c.id, 1);
      expect(c.monto, 35.5);
      expect(c.descripcion, '2 batidos proteína');
      expect(c.fecha, '2026-05-03');
    });

    test('fromJson convierte monto entero a double', () {
      final json = {
        'id': 1,
        'membresiaId': 1,
        'clubId': 1,
        'descripcion': 'test',
        'monto': 30,
        'fecha': '2026-05-03',
        'registradaPorHostId': 1,
      };
      final c = CompraManual.fromJson(json);
      expect(c.monto, 30.0);
      expect(c.monto, isA<double>());
    });

    test('fromJson usa 0 como registradaPorHostId cuando es null', () {
      final json = {
        'id': 1,
        'membresiaId': 1,
        'clubId': 1,
        'descripcion': 'test',
        'monto': 10.0,
        'fecha': '2026-05-03',
      };
      final c = CompraManual.fromJson(json);
      expect(c.registradaPorHostId, 0);
    });
  });
}
