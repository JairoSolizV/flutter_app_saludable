import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/resumen_mensual_ventas.dart';

/// Tabla de ventas e ingresos por día del mes (ancho completo, sin scroll horizontal).
class VentasPorDiaMesTable extends StatelessWidget {
  final List<VentasPorDiaMes> filas;

  const VentasPorDiaMesTable({super.key, required this.filas});

  static final _moneda = NumberFormat('#,##0.00', 'es_BO');
  static final _fecha = DateFormat('dd/MM');
  static const _green = AppTheme.primaryColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: _green.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Expanded(
                child: Text(
                  'Ventas',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Ingresos (Bs.)',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filas.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final f = filas[index];
            final sinActividad = f.totalVentas == 0 && f.totalIngresosBs == 0;
            final style = sinActividad
                ? TextStyle(color: Colors.grey.shade400, fontSize: 13)
                : const TextStyle(fontSize: 13);
            final boldStyle = sinActividad
                ? style
                : style.copyWith(fontWeight: FontWeight.w600);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(_fecha.format(f.fecha), style: style)),
                  Expanded(
                    child: Text(
                      '${f.totalVentas}',
                      textAlign: TextAlign.center,
                      style: boldStyle,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _moneda.format(f.totalIngresosBs),
                      textAlign: TextAlign.end,
                      style: boldStyle,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Ranking de productos más vendidos del mes (top 10 en pantalla).
class TopProductosMesList extends StatelessWidget {
  final List<TopProductoMes> productos;
  final int maxItems;

  const TopProductosMesList({
    super.key,
    required this.productos,
    this.maxItems = 10,
  });

  @override
  Widget build(BuildContext context) {
    final top = productos.take(maxItems).toList();
    if (top.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Sin productos vendidos este mes',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < top.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    top[i].nombre,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ),
                Text(
                  '${top[i].cantidadVendida}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
