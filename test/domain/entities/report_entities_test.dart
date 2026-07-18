import 'package:flutter_app_saludable/domain/entities/resumen_mensual_ventas.dart';
import 'package:flutter_app_saludable/domain/entities/ventas_diarias_reporte.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResumenMesKpi', () {
    test('fromJson parsea valores presentes', () {
      final kpi = ResumenMesKpi.fromJson({
        'totalVentas': 10,
        'totalIngresosBs': 150.5,
      });
      expect(kpi.totalVentas, 10);
      expect(kpi.totalIngresosBs, 150.5);
    });

    test('fromJson usa valores por defecto si faltan', () {
      final kpi = ResumenMesKpi.fromJson({});
      expect(kpi.totalVentas, 0);
      expect(kpi.totalIngresosBs, 0);
    });
  });

  group('VentasPorDiaMes', () {
    test('fromJson parsea fecha y totales', () {
      final v = VentasPorDiaMes.fromJson({
        'fecha': '2024-03-01',
        'totalVentas': 5,
        'totalIngresosBs': 30.0,
      });
      expect(v.fecha, DateTime.parse('2024-03-01'));
      expect(v.totalVentas, 5);
    });
  });

  group('TopProductoMes', () {
    test('fromJson parsea con productoId', () {
      final p = TopProductoMes.fromJson({
        'productoId': 7,
        'nombre': 'Batido',
        'cantidadVendida': 3,
      });
      expect(p.productoId, 7);
      expect(p.nombre, 'Batido');
    });

    test('fromJson sin nombre usa cadena vacía', () {
      final p = TopProductoMes.fromJson({'cantidadVendida': 1});
      expect(p.nombre, '');
      expect(p.productoId, isNull);
    });
  });

  group('ResumenMensualVentas', () {
    test('fromJson parsea estructura completa con listas anidadas', () {
      final resumen = ResumenMensualVentas.fromJson({
        'clubId': 1,
        'nombreClub': 'Club Norte',
        'anio': 2024,
        'mes': 3,
        'nombreMes': 'Marzo',
        'resumen': {'totalVentas': 20, 'totalIngresosBs': 500.0},
        'ventasPorDia': [
          {'fecha': '2024-03-01', 'totalVentas': 5, 'totalIngresosBs': 100.0},
          {'fecha': '2024-03-02', 'totalVentas': 15, 'totalIngresosBs': 400.0},
        ],
        'topProductos': [
          {'productoId': 1, 'nombre': 'Batido', 'cantidadVendida': 10},
        ],
      });

      expect(resumen.clubId, 1);
      expect(resumen.ventasPorDia, hasLength(2));
      expect(resumen.topProductos, hasLength(1));
      expect(resumen.etiquetaPeriodo, 'Marzo 2024');
    });

    test('fromJson sin listas usa colecciones vacías', () {
      final resumen = ResumenMensualVentas.fromJson({
        'resumen': <String, dynamic>{},
      });
      expect(resumen.ventasPorDia, isEmpty);
      expect(resumen.topProductos, isEmpty);
      expect(resumen.clubId, 0);
    });
  });

  group('ProductoVentaDiaria', () {
    test('fromJson parsea combo y calcula etiquetaCorta con cantidad',
        () {
      final p = ProductoVentaDiaria.fromJson({
        'productoId': 1,
        'nombre': 'Combo Familiar',
        'cantidad': 3,
        'esCombo': true,
        'subtotal': 45.0,
      });
      expect(p.esCombo, isTrue);
      expect(p.etiquetaCorta, 'Combo Familiar (x3)');
    });

    test('etiquetaCorta sin repetir cantidad cuando es 1', () {
      final p = ProductoVentaDiaria.fromJson({
        'nombre': 'Te',
        'cantidad': 1,
        'subtotal': 10.0,
      });
      expect(p.etiquetaCorta, 'Te');
    });
  });

  group('RegistroVentaDiaria', () {
    test('fromJson parsea productos anidados y productosTexto los concatena',
        () {
      final registro = RegistroVentaDiaria.fromJson({
        'numeroFila': 1,
        'fecha': '2024-03-01',
        'hora': '10:00',
        'nombre': 'Ana',
        'estatusVisita': 'COMPLETADA',
        'numeroSocio': 'S-1',
        'productos': [
          {'nombre': 'Batido', 'cantidad': 2, 'subtotal': 20.0},
          {'nombre': 'Te', 'cantidad': 1, 'subtotal': 10.0},
        ],
        'tipoPago': 'PUNTOS',
        'totalBs': 30.0,
        'origen': 'APP',
        'pedidoId': 55,
      });

      expect(registro.productos, hasLength(2));
      expect(registro.productosTexto, 'Batido (x2), Te');
      expect(registro.pedidoId, 55);
    });

    test('fromJson con campos opcionales ausentes usa valores por defecto',
        () {
      final registro = RegistroVentaDiaria.fromJson({
        'fecha': '2024-03-01',
      });
      expect(registro.numeroSocio, isNull);
      expect(registro.tipoPago, isNull);
      expect(registro.productos, isEmpty);
      expect(registro.origen, '');
    });
  });

  group('RankingProductoDia', () {
    test('fromJson parsea nombre y cantidad', () {
      final r = RankingProductoDia.fromJson({
        'nombre': 'Batido',
        'cantidad': 12,
      });
      expect(r.nombre, 'Batido');
      expect(r.cantidad, 12);
    });
  });

  group('ResumenDiaVentas', () {
    test('fromJson parsea ingresos por tipo de pago y ranking', () {
      final resumen = ResumenDiaVentas.fromJson({
        'fecha': '2024-03-01',
        'totalVentas': 8,
        'totalIngresosBs': 120.0,
        'ingresosPorTipoPago': {'EFECTIVO': 80.0, 'PUNTOS': 40.0},
        'conteoNuevos': 2,
        'conteoReferidos': 1,
        'rankingProductos': [
          {'nombre': 'Batido', 'cantidad': 5},
        ],
      });

      expect(resumen.ingresosPorTipoPago['EFECTIVO'], 80.0);
      expect(resumen.rankingProductos, hasLength(1));
    });

    test('fromJson sin mapas ni listas usa valores vacíos', () {
      final resumen = ResumenDiaVentas.fromJson({'fecha': '2024-03-01'});
      expect(resumen.ingresosPorTipoPago, isEmpty);
      expect(resumen.rankingProductos, isEmpty);
      expect(resumen.conteoNuevos, 0);
    });
  });

  group('VentasDiariasReporte', () {
    test('fromJson parsea filas y resumen anidado', () {
      final reporte = VentasDiariasReporte.fromJson({
        'clubId': 1,
        'nombreClub': 'Club Norte',
        'fecha': '2024-03-01',
        'resumen': {
          'fecha': '2024-03-01',
          'totalVentas': 3,
          'totalIngresosBs': 60.0,
          'conteoNuevos': 1,
          'conteoReferidos': 0,
        },
        'filas': [
          {
            'numeroFila': 1,
            'fecha': '2024-03-01',
            'hora': '09:00',
            'nombre': 'Beto',
            'estatusVisita': 'COMPLETADA',
            'totalBs': 20.0,
            'origen': 'APP',
            'pedidoId': 1,
          },
        ],
      });

      expect(reporte.clubId, 1);
      expect(reporte.filas, hasLength(1));
      expect(reporte.resumen.totalVentas, 3);
    });

    test('fromJson sin filas usa lista vacía', () {
      final reporte = VentasDiariasReporte.fromJson({
        'fecha': '2024-03-01',
        'resumen': {'fecha': '2024-03-01'},
      });
      expect(reporte.filas, isEmpty);
    });
  });
}
