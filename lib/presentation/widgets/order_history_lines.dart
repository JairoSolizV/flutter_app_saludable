import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/utils/bolivian_price.dart';
import 'package:flutter_app_saludable/core/utils/order_combo_history_display.dart';
import 'package:flutter_app_saludable/core/utils/order_item_options_display.dart';
import 'package:flutter_app_saludable/domain/entities/order_combo.dart';

/// Bloques de historial para combos modernos y productos sueltos.
class OrderHistoryLines extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool showPrice;
  final bool hostPreparationStyle;

  const OrderHistoryLines({
    super.key,
    required this.order,
    this.showPrice = true,
    this.hostPreparationStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final combos = PedidoComboSnapshot.listFromOrder(order);
    final standalone = OrderComboHistoryDisplay.standaloneItems(order);
    final legacyComboItems = OrderComboHistoryDisplay.legacyComboItems(order);

    if (combos.isEmpty && standalone.isEmpty && legacyComboItems.isEmpty) {
      return const Text(
        'Sin detalle de productos',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final combo in combos) _modernComboBlock(combo),
        for (final item in standalone) _standaloneItem(item),
        for (final item in legacyComboItems) _legacyComboItem(item),
      ],
    );
  }

  Widget _modernComboBlock(PedidoComboSnapshot combo) {
    final title = hostPreparationStyle
        ? '${combo.comboName} ×${combo.quantity}'
        : combo.comboName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: hostPreparationStyle ? 16 : 14,
              color: hostPreparationStyle ? Colors.black87 : null,
            ),
          ),
          if (showPrice) ...[
            const SizedBox(height: 2),
            Text(
              BolivianPrice.formatBs(combo.subtotal),
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
          if (!hostPreparationStyle)
            Text(
              'Cantidad: ${combo.quantity}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          if (!hostPreparationStyle) ...[
            const SizedBox(height: 4),
            Text(
              'Incluye:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
          for (final component in combo.items) ...[
            SizedBox(height: hostPreparationStyle ? 8 : 4),
            Text(
              component.productoNombre,
              style: TextStyle(
                fontSize: hostPreparationStyle ? 15 : 13,
                fontWeight:
                    hostPreparationStyle ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            for (final line in _componentOptionLines(component))
              Padding(
                padding: EdgeInsets.only(
                  left: hostPreparationStyle ? 12 : 12,
                  top: hostPreparationStyle ? 4 : 2,
                ),
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: hostPreparationStyle ? 14 : 12,
                    color: Colors.grey[hostPreparationStyle ? 800 : 700],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<String> _componentOptionLines(PedidoComboItemSnapshot component) {
    if (hostPreparationStyle) {
      return OrderItemOptionsDisplay.hostBulletLines(component.options);
    }
    return OrderComboHistoryDisplay.componentOptionLinesFromSnapshot(component);
  }

  Widget _standaloneItem(Map<String, dynamic> item) {
    final cantidad = item['cantidad'] as int? ?? 1;
    final productoNombre = item['productoNombre']?.toString() ?? 'Producto';
    final nota = item['nota']?.toString();
    final options =
        OrderItemOptionsDisplay.parseFromHistoryItem(item);
    final optionLines = hostPreparationStyle
        ? OrderItemOptionsDisplay.hostBulletLines(options)
        : OrderItemOptionsDisplay.groupLines(options);

    return Padding(
      padding: EdgeInsets.only(bottom: hostPreparationStyle ? 12 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hostPreparationStyle
                ? '• $cantidad x $productoNombre'
                : '• $cantidad x $productoNombre',
            style: TextStyle(
              fontSize: hostPreparationStyle ? 16 : 13,
              fontWeight:
                  hostPreparationStyle ? FontWeight.bold : FontWeight.normal,
              color: hostPreparationStyle ? Colors.black87 : null,
            ),
          ),
          if (nota != null && nota.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                hostPreparationStyle ? 'Nota: $nota' : '($nota)',
                style: TextStyle(
                  fontSize: hostPreparationStyle ? 14 : 12,
                  color: hostPreparationStyle ? Colors.red[700] : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                  fontWeight:
                      hostPreparationStyle ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          for (final line in optionLines)
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                top: hostPreparationStyle ? 4 : 2,
              ),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: hostPreparationStyle ? 14 : 12,
                  color: Colors.grey[hostPreparationStyle ? 800 : 700],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legacyComboItem(Map<String, dynamic> item) {
    return _standaloneItem(item);
  }
}
