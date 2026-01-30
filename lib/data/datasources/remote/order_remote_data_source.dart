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
    // Validar que tenemos los IDs necesarios
    if (order.membresiaId == null) {
      throw Exception('Error: El pedido debe incluir membresiaId');
    }
    if (order.clubId == null) {
      throw Exception('Error: El pedido debe incluir clubId');
    }

    final int membresiaId = order.membresiaId!;
    final int clubId = order.clubId!;

    print('[DEBUG] Enviando pedido - membresiaId: $membresiaId, clubId: $clubId, items: ${items.length}');

    try {
      // La API actual: POST /api/pedidos?membresiaId={...}&clubId={...}&productoId={...}
      // El backend espera: cantidad, tipoConsumo, observaciones en el body
      for (var item in items) {
        // Convertir productId de String a int para el backend
        final int productoId = int.parse(item.productId);
        
        // Combinar nota general del pedido con nota específica del item
        String observacionesCompletas = '';
        if (order.observaciones != null && order.observaciones!.isNotEmpty) {
          observacionesCompletas = order.observaciones!;
        }
        if (item.note.isNotEmpty) {
          if (observacionesCompletas.isNotEmpty) {
            observacionesCompletas += ' | ';
          }
          observacionesCompletas += item.note;
        }
        if (observacionesCompletas.isEmpty) {
          observacionesCompletas = 'Pedido desde App Móvil';
        }
        
        print('[DEBUG] Enviando item - productoId: $productoId, cantidad: ${item.quantity}, tipoConsumo: ${order.tipoConsumo ?? "EN_LUGAR"}');
        
        // Enviar una petición por cada unidad (el backend maneja cantidad en el body)
        // Pero según el código del backend, parece que se envía una petición por unidad
        for (int i = 0; i < item.quantity; i++) {
          await _client.post(
            '/pedidos',
            queryParameters: {
              'membresiaId': membresiaId,
              'clubId': clubId,
              'productoId': productoId,
            },
            data: {
              'cantidad': 1, // Cada petición es 1 unidad
              'tipoConsumo': order.tipoConsumo ?? 'EN_LUGAR', // 'EN_LUGAR' o 'PARA_LLEVAR'
              'observaciones': observacionesCompletas,
              'estado': 'RECIBIDO', // Estado inicial según el backend
              'fechaPedido': DateTime.now().toIso8601String(),
            }
          );
        }
      }
      
      print('[DEBUG] Pedido enviado exitosamente');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['message'] ?? e.message ?? 'Error desconocido';
      print('[DEBUG] Error enviando pedido - Status: $statusCode, Error: $errorMessage');
      throw Exception('Error enviando pedido: $errorMessage');
    }
  }
}
