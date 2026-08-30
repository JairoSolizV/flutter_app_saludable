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

    return {
      'id': order.id,
      'pedidoId': order.id,
      'localId': order.id,
      'isLocalPending': true,
      'fecha': order.createdAt,
      'estado': 'LOCAL_PENDING',
      'clubNombre': clubNombreFallback ?? 'Club',
      'tipoConsumo': order.tipoConsumo ?? 'EN_LUGAR',
      'observaciones': order.observaciones ?? '',
      'tiempoEstimadoMinutos': order.tiempoEstimadoMinutos,
      'items': items,
    };
  }
}
