import '../../../core/orders/order_sync_status.dart';
import '../../../domain/entities/order_entity.dart';

/// Convierte pedidos locales pendientes al formato de UI de [MemberOrdersListScreen].
class MemberLocalOrderMapper {
  MemberLocalOrderMapper._();

  static Map<String, dynamic> toUiMap(
    OrderEntity order, {
    String? clubNombreFallback,
  }) {
    final items = order.items.map((item) {
      return {
        'productoNombre':
            item.productName.isNotEmpty ? item.productName : 'Producto',
        'cantidad': item.quantity,
        'nota': item.note,
        'opciones': item.options
            .map(
              (o) => {
                'grupoId': o.groupId,
                'grupoNombre': o.groupName,
                'grupoOrden': o.groupOrder,
                'opcionId': o.optionId,
                'opcionNombre': o.optionName,
                'opcionOrden': o.optionOrder,
                'cantidad': o.quantity,
              },
            )
            .toList(),
      };
    }).toList();

    final combos = order.combos.map((combo) {
      return {
        'comboId': combo.comboId,
        'comboNombre': combo.comboName,
        'cantidad': combo.quantity,
        'precioUnitario': combo.priceSnapshot,
        'subtotal': combo.priceSnapshot * combo.quantity,
        'puntosValor': combo.pointsSnapshot,
        'items': combo.components
            .map(
              (c) => {
                'productoId': c.productId,
                'productoNombre': c.productName,
                'cantidad': 1,
                'opciones': c.options
                    .map(
                      (o) => {
                        'grupoId': o.groupId,
                        'grupoNombre': o.groupName,
                        'grupoOrden': o.groupOrder,
                        'opcionId': o.optionId,
                        'opcionNombre': o.optionName,
                        'opcionOrden': o.optionOrder,
                        'cantidad': o.quantity,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      };
    }).toList();

    final isFailed = order.syncStatus == OrderSyncStatus.failedPermanent;
    final estado = isFailed ? 'LOCAL_FAILED' : 'LOCAL_PENDING';

    return {
      'id': order.id,
      'pedidoId': order.id,
      'localId': order.id,
      'isLocalPending': !isFailed,
      'isLocalFailed': isFailed,
      'syncErrorCode': order.syncErrorCode,
      'syncErrorMessage': order.syncErrorMessage,
      'fecha': order.createdAt,
      'estado': estado,
      'clubNombre': clubNombreFallback ?? 'Club',
      'tipoConsumo': order.tipoConsumo ?? 'EN_LUGAR',
      'observaciones': order.observaciones ?? '',
      'tiempoEstimadoMinutos': order.tiempoEstimadoMinutos,
      'items': items,
      if (combos.isNotEmpty) 'combos': combos,
    };
  }
}
