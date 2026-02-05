import 'package:dio/dio.dart';
import '../../../domain/entities/order_entity.dart';

abstract class OrderRemoteDataSource {
  Future<void> sendOrder(OrderEntity order, List<OrderItem> items);
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId);
  Future<void> updateOrderStatus(int pedidoId, String newStatus);
  Future<List<Map<String, dynamic>>> getAllOrders(); // Método temporal para debug
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
        
        // IMPORTANTE: El backend puede obtener el clubId de la membresía automáticamente
        // Por lo tanto, puede que no necesitemos enviar clubId en queryParams
        // Pero lo enviamos por si acaso el backend lo requiere explícitamente
        
        // Enviar una petición por cada unidad (el backend maneja cantidad en el body)
        // Pero según el código del backend, parece que se envía una petición por unidad
        for (int i = 0; i < item.quantity; i++) {
          print('[DEBUG SEND] Enviando POST /pedidos con:');
          print('[DEBUG SEND]   QueryParams: membresiaId=$membresiaId, clubId=$clubId, productoId=$productoId');
          print('[DEBUG SEND]   Body: cantidad=1, tipoConsumo=${order.tipoConsumo ?? "EN_LUGAR"}, observaciones=$observacionesCompletas');
          
          try {
            final response = await _client.post(
              '/pedidos',
              queryParameters: {
                'membresiaId': membresiaId,
                'clubId': clubId, // Enviar clubId explícitamente
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
            
            print('[DEBUG SEND] Respuesta del POST /pedidos - Status: ${response.statusCode}');
            if (response.statusCode == 201 || response.statusCode == 200) {
              print('[DEBUG SEND] Pedido enviado exitosamente. Response: ${response.data}');
              print('[DEBUG SEND] Response data completo: ${response.data}');
            } else {
              print('[DEBUG SEND] WARNING: Status code inesperado: ${response.statusCode}');
            }
          } on DioException catch (e) {
            print('[DEBUG SEND] ERROR al enviar pedido:');
            print('[DEBUG SEND]   Status: ${e.response?.statusCode}');
            print('[DEBUG SEND]   Message: ${e.message}');
            print('[DEBUG SEND]   Response data: ${e.response?.data}');
            rethrow;
          }
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

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async {
    try {
      print('[DEBUG GET] Obteniendo pedidos para clubId: $clubId');
      print('[DEBUG GET] Endpoint: GET /pedidos/club/$clubId');
      
      // NOTA: El backend puede buscar pedidos donde:
      // 1. El pedido tiene clubId directamente, O
      // 2. La membresía del pedido tiene clubId
      // Por eso es importante verificar la estructura de respuesta
      
      final response = await _client.get('/pedidos/club/$clubId');
      
      print('[DEBUG GET] Respuesta recibida - Status: ${response.statusCode}');
      print('[DEBUG GET] Tipo de data: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        final dynamic data = response.data;
        List<Map<String, dynamic>> orders = [];
        
        if (data is List) {
          print('[DEBUG GET] Data es una Lista con ${data.length} elementos');
          if (data.isNotEmpty) {
            print('[DEBUG GET] Ejemplo del primer elemento: ${data.first}');
            // Verificar estructura del pedido
            final firstOrder = data.first as Map<String, dynamic>;
            print('[DEBUG GET] Keys del primer pedido: ${firstOrder.keys.toList()}');
            
            // Verificar si tiene clubId directo o a través de membresia
            if (firstOrder.containsKey('clubId')) {
              print('[DEBUG GET] El pedido tiene clubId directo: ${firstOrder['clubId']}');
            } else if (firstOrder.containsKey('membresia')) {
              final membresia = firstOrder['membresia'] as Map<String, dynamic>?;
              if (membresia != null && membresia.containsKey('clubId')) {
                print('[DEBUG GET] El pedido tiene clubId a través de membresia: ${membresia['clubId']}');
              }
            }
          }
          orders = data.cast<Map<String, dynamic>>();
        } else if (data is Map) {
          print('[DEBUG GET] Data es un Map con keys: ${data.keys.toList()}');
          if (data.containsKey('content') && data['content'] is List) {
            orders = (data['content'] as List).cast<Map<String, dynamic>>();
            print('[DEBUG GET] Pedidos en content: ${orders.length}');
          } else if (data.containsKey('data') && data['data'] is List) {
            orders = (data['data'] as List).cast<Map<String, dynamic>>();
            print('[DEBUG GET] Pedidos en data: ${orders.length}');
          } else {
            print('[DEBUG GET] WARNING: Data es Map pero no tiene content ni data. Keys: ${data.keys}');
            print('[DEBUG GET] Data completo: $data');
          }
        } else {
          print('[DEBUG GET] WARNING: Data tiene tipo inesperado: ${data.runtimeType}');
          print('[DEBUG GET] Data: $data');
        }
        
        print('[DEBUG GET] Total de pedidos obtenidos: ${orders.length}');
        if (orders.isNotEmpty) {
          print('[DEBUG GET] Estructura del primer pedido:');
          print('[DEBUG GET] Keys: ${orders.first.keys.toList()}');
          print('[DEBUG GET] Primer pedido completo: ${orders.first}');
        } else {
          print('[DEBUG GET] IMPORTANTE: No se encontraron pedidos para clubId: $clubId');
          print('[DEBUG GET] Esto puede significar:');
          print('[DEBUG GET]   1. No hay pedidos creados aún');
          print('[DEBUG GET]   2. Los pedidos se guardaron con un clubId diferente');
          print('[DEBUG GET]   3. El backend busca pedidos por membresia.clubId y no coincide');
        }
        
        return orders;
      } else {
        throw Exception('Error al obtener pedidos: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      print('[DEBUG GET] DioException - Status: $statusCode');
      print('[DEBUG GET] Response data: $responseData');
      
      String errorMessage = 'Error desconocido';
      if (responseData is Map) {
        errorMessage = responseData['message']?.toString() ?? 
                      responseData['error']?.toString() ?? 
                      e.message ?? 'Error desconocido';
      } else if (responseData is String) {
        errorMessage = responseData;
      } else {
        errorMessage = e.message ?? 'Error desconocido';
      }
      
      print('[DEBUG GET] Error obteniendo pedidos - Status: $statusCode, Error: $errorMessage');
      throw Exception('Error obteniendo pedidos: $errorMessage');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() async {
    try {
      print('[DEBUG ALL] Obteniendo TODOS los pedidos (sin filtrar por club)');
      print('[DEBUG ALL] Endpoint: GET /pedidos');
      
      final response = await _client.get('/pedidos');
      
      print('[DEBUG ALL] Respuesta recibida - Status: ${response.statusCode}');
      print('[DEBUG ALL] Tipo de data: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        final dynamic data = response.data;
        List<Map<String, dynamic>> orders = [];
        
        if (data is List) {
          print('[DEBUG ALL] Data es una Lista con ${data.length} elementos');
          orders = data.cast<Map<String, dynamic>>();
        } else if (data is Map) {
          if (data.containsKey('content') && data['content'] is List) {
            orders = (data['content'] as List).cast<Map<String, dynamic>>();
          } else if (data.containsKey('data') && data['data'] is List) {
            orders = (data['data'] as List).cast<Map<String, dynamic>>();
          }
        }
        
        print('[DEBUG ALL] Total de pedidos en la BD: ${orders.length}');
        if (orders.isNotEmpty) {
          print('[DEBUG ALL] Primeros 3 pedidos:');
          for (int i = 0; i < orders.length && i < 3; i++) {
            final order = orders[i];
            print('[DEBUG ALL] Pedido ${i + 1}:');
            print('[DEBUG ALL]   ID: ${order['id']}');
            print('[DEBUG ALL]   Keys: ${order.keys.toList()}');
            if (order.containsKey('clubId')) {
              print('[DEBUG ALL]   clubId directo: ${order['clubId']}');
            }
            if (order.containsKey('membresia')) {
              final membresia = order['membresia'];
              if (membresia is Map) {
                print('[DEBUG ALL]   membresia.clubId: ${membresia['clubId']}');
                print('[DEBUG ALL]   membresia.id: ${membresia['id']}');
              }
            }
          }
        }
        
        return orders;
      } else {
        throw Exception('Error al obtener todos los pedidos: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('[DEBUG ALL] Error obteniendo todos los pedidos: ${e.message}');
      throw Exception('Error obteniendo todos los pedidos: ${e.message}');
    }
  }

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus) async {
    try {
      print('[DEBUG] Actualizando estado del pedido $pedidoId a $newStatus');
      final response = await _client.patch(
        '/pedidos/$pedidoId/estado',
        data: {'estado': newStatus},
      );
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al actualizar estado: ${response.statusCode}');
      }
      
      print('[DEBUG] Estado actualizado exitosamente');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['message'] ?? e.message ?? 'Error desconocido';
      print('[DEBUG] Error actualizando estado - Status: $statusCode, Error: $errorMessage');
      throw Exception('Error actualizando estado: $errorMessage');
    }
  }
}
