import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/ventas_diarias_reporte.dart';
import '../../core/theme/app_theme.dart';

/// Tabla horizontal del registro diario de ventas (estilo hoja de papel).
class VentasDiariasTable extends StatelessWidget {
  final List<RegistroVentaDiaria> filas;

  const VentasDiariasTable({super.key, required this.filas});

  static final _moneda = NumberFormat('#,##0.00', 'es_BO');
  static const _green = AppTheme.primaryColor;

  @override
  Widget build(BuildContext context) {
    if (filas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Sin ventas registradas este día',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(_green.withValues(alpha: 0.12)),
        columnSpacing: 16,
        horizontalMargin: 12,
        columns: const [
          DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('N/R', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Productos', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Pago', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Total Bs.', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Hora', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: filas.map((f) {
          final nombre = f.nombre.isNotEmpty ? f.nombre : '—';
          final nr = f.estatusVisita.isNotEmpty ? f.estatusVisita : '—';
          final pago = f.tipoPago ?? '—';
          return DataRow(cells: [
            DataCell(Text('${f.numeroFila}')),
            DataCell(_BadgeNR(valor: nr)),
            DataCell(SizedBox(width: 100, child: Text(nombre, overflow: TextOverflow.ellipsis))),
            DataCell(SizedBox(
              width: 160,
              child: Text(f.productosTexto, overflow: TextOverflow.ellipsis, maxLines: 2),
            )),
            DataCell(Text(pago)),
            DataCell(Text(_moneda.format(f.totalBs))),
            DataCell(Text(f.hora)),
          ]);
        }).toList(),
      ),
    );
  }
}

class _BadgeNR extends StatelessWidget {
  final String valor;

  const _BadgeNR({required this.valor});

  @override
  Widget build(BuildContext context) {
    if (valor == '—') {
      return Text(valor, style: TextStyle(color: Colors.grey.shade500));
    }
    Color bg;
    Color fg;
    switch (valor) {
      case 'N':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'R':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(valor, style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 12)),
    );
  }
}
