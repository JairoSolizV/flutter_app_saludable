import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app_saludable/domain/entities/pre_socio.dart';
import 'package:flutter_app_saludable/domain/entities/mision_pre_socio.dart';

void main() {
  group('MisionPreSocio', () {
    test('fromJson parsea campos correctamente', () {
      final json = {
        'id': 1,
        'preSocioId': 2,
        'nombre': 'Consumir 3 combos',
        'descripcion': 'Combo proteínas',
        'metaCantidad': 3,
        'progresoActual': 2,
        'fechaLimite': '2026-05-10',
        'completada': false,
      };
      final m = MisionPreSocio.fromJson(json);
      expect(m.id, 1);
      expect(m.nombre, 'Consumir 3 combos');
      expect(m.metaCantidad, 3);
      expect(m.progresoActual, 2);
      expect(m.completada, false);
    });

    test('porcentaje calcula correctamente', () {
      final m = MisionPreSocio(
        id: 1,
        preSocioId: 1,
        nombre: 'Test',
        metaCantidad: 4,
        progresoActual: 2,
        completada: false,
      );
      expect(m.porcentaje, 0.5);
    });

    test('porcentaje no supera 1.0', () {
      final m = MisionPreSocio(
        id: 1,
        preSocioId: 1,
        nombre: 'Test',
        metaCantidad: 2,
        progresoActual: 5,
        completada: true,
      );
      expect(m.porcentaje, 1.0);
    });

    test('porcentaje es 0 con metaCantidad 0', () {
      final m = MisionPreSocio(
        id: 1,
        preSocioId: 1,
        nombre: 'Test',
        metaCantidad: 0,
        progresoActual: 0,
        completada: false,
      );
      expect(m.porcentaje, 0.0);
    });
  });

  group('PreSocio', () {
    test('fromJson parsea campos correctamente', () {
      final json = {
        'id': 10,
        'clubId': 5,
        'nombre': 'Ana García',
        'telefono': '77712345',
        'referidoPorMembresiaId': 12,
        'referidoPorNombre': 'Carlos López',
        'fechaCreacion': '2026-05-03',
        'estado': 'EN_SEGUIMIENTO',
        'misiones': [],
      };
      final p = PreSocio.fromJson(json);
      expect(p.id, 10);
      expect(p.nombre, 'Ana García');
      expect(p.estado, 'EN_SEGUIMIENTO');
      expect(p.misiones, isEmpty);
      expect(p.referidoPorNombre, 'Carlos López');
    });

    test('fromJson parsea misiones anidadas', () {
      final json = {
        'id': 1,
        'clubId': 1,
        'nombre': 'Test',
        'telefono': '123',
        'fechaCreacion': '2026-05-03',
        'estado': 'EN_SEGUIMIENTO',
        'misiones': [
          {
            'id': 1,
            'preSocioId': 1,
            'nombre': 'M1',
            'metaCantidad': 3,
            'progresoActual': 3,
            'completada': true,
          }
        ],
      };
      final p = PreSocio.fromJson(json);
      expect(p.misiones.length, 1);
      expect(p.misiones.first.nombre, 'M1');
    });

    test('todasMisionesCompletas es false cuando hay misiones incompletas', () {
      final p = PreSocio(
        id: 1,
        clubId: 1,
        nombre: 'Test',
        telefono: '123',
        fechaCreacion: '2026-05-03',
        estado: 'EN_SEGUIMIENTO',
        misiones: [
          MisionPreSocio(
              id: 1,
              preSocioId: 1,
              nombre: 'M1',
              metaCantidad: 3,
              progresoActual: 3,
              completada: true),
          MisionPreSocio(
              id: 2,
              preSocioId: 1,
              nombre: 'M2',
              metaCantidad: 3,
              progresoActual: 1,
              completada: false),
        ],
      );
      expect(p.todasMisionesCompletas, false);
    });

    test('todasMisionesCompletas es true cuando todas completas', () {
      final p = PreSocio(
        id: 1,
        clubId: 1,
        nombre: 'Test',
        telefono: '123',
        fechaCreacion: '2026-05-03',
        estado: 'EN_SEGUIMIENTO',
        misiones: [
          MisionPreSocio(
              id: 1,
              preSocioId: 1,
              nombre: 'M1',
              metaCantidad: 3,
              progresoActual: 3,
              completada: true),
        ],
      );
      expect(p.todasMisionesCompletas, true);
    });

    test('progresoGlobal es 0 sin misiones', () {
      final p = PreSocio(
        id: 1,
        clubId: 1,
        nombre: 'Test',
        telefono: '123',
        fechaCreacion: '2026-05-03',
        estado: 'EN_SEGUIMIENTO',
      );
      expect(p.progresoGlobal, 0.0);
    });

    test('progresoGlobal calcula porcentaje de misiones completas', () {
      final p = PreSocio(
        id: 1,
        clubId: 1,
        nombre: 'Test',
        telefono: '123',
        fechaCreacion: '2026-05-03',
        estado: 'EN_SEGUIMIENTO',
        misiones: [
          MisionPreSocio(
              id: 1,
              preSocioId: 1,
              nombre: 'M1',
              metaCantidad: 1,
              progresoActual: 1,
              completada: true),
          MisionPreSocio(
              id: 2,
              preSocioId: 1,
              nombre: 'M2',
              metaCantidad: 1,
              progresoActual: 0,
              completada: false),
        ],
      );
      expect(p.progresoGlobal, 0.5);
    });
  });
}
