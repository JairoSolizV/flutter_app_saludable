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
      // Requiere envío individual por producto con cantidad
      for (var item in items) {
        // Convertir productId de String a int para el backend
        final int productoId = int.parse(item.productId);
        
        print('[DEBUG] Enviando item - productoId: $productoId, cantidad: ${item.quantity}');
        
        // Enviar una petición por cada unidad (o el backend puede manejar cantidad)
        // Por ahora enviamos una petición por cada unidad según la API actual
        for (int i = 0; i < item.quantity; i++) {
          await _client.post(
            '/pedidos',
            queryParameters: {
              'membresiaId': membresiaId,
              'clubId': clubId,
              'productoId': productoId,
            },
            data: {
              'estado': 'PENDIENTE',
              'fecha': DateTime.now().toIso8601String(),
              'notas': 'Pedido desde App Móvil'
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
