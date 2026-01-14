import 'package:dio/dio.dart';
import '../../../domain/entities/order_entity.dart';

abstract class OrderRemoteDataSource {
  Future<void> sendOrder(OrderEntity order, List<OrderItem> items);
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final Dio _client;

  OrderRemoteDataSourceImpl(this._client);

  @override
  Future<void> sendOrder(OrderEntity order, List<OrderItem> items) async {
    // La API actual: POST /api/pedidos?membresiaId={...}&clubId={...}&productoId={...}
    // Requiere envío individual por producto.
    // Asumiremos que tenemos el ID de membresía del usuario (o usamos su ID de usuario si es lo mismo)
    // y un clubId hardcodeado o seleccionado.
    
    // Obtener membresiaId. Por ahora usamos el userId del pedido.
    final String membresiaId = "1"; // TODO: Obtener dinamico
    final String clubId = "1"; // TODO: Obtener dinamico (club actual)

    try {
      for (var item in items) {
          // Si la cantidad es > 1, ¿debemos enviar X peticiones?
          // Asumiremos que PedidoDTO (body) puede llevar cantidad o notas.
          // Si no, enviamos loop por cantidad.
          // Dado que no tengo la definición de PedidoDTO, enviaré un Request por cada ITEM (producto diferente).
          // Y repetiré la llamada por la cantidad vececes (peor caso) o asumiré que backend lo maneja.
          // Estrategia segura: Enviar N veces si quantity=N.
          
          for (int i = 0; i < item.quantity; i++) {
             await _client.post(
                '/pedidos',
                queryParameters: {
                   'membresiaId': membresiaId,
                   'clubId': clubId,
                   'productoId': item.productId,
                },
                data: {
                   // PedidoDTO body placeholder
                   'estado': 'PENDIENTE',
                   'fecha': DateTime.now().toIso8601String(),
                   'notas': 'Pedido desde App Móvil'
                }
             );
          }
      }
    } on DioException catch (e) {
       throw Exception('Error enviando pedido: ${e.message}');
    }
  }
}
