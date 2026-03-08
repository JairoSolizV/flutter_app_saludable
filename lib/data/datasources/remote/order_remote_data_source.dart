import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/order_entity.dart';

abstract class OrderRemoteDataSource {
  Future<void> sendOrder(OrderEntity order, List<OrderItem> items);
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId);
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId);
  Future<void> updateOrderStatus(int pedidoId, String newStatus, {int? tiempoEstimadoMinutos});
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
    if (items.isEmpty) {
      throw Exception('Error: El pedido debe tener al menos un item');
    }

    final int membresiaId = order.membresiaId!;
    final int clubId = order.clubId!;

    debugPrint('[DEBUG SEND] Enviando pedido con múltiples items - membresiaId: $membresiaId, clubId: $clubId, items: ${items.length}');

    try {
      // Preparar items para el backend
      final List<Map<String, dynamic>> itemsData = [];
      for (var item in items) {
        final int productoId = int.parse(item.productId);
        itemsData.add({
          'productoId': productoId,
          'cantidad': item.quantity,
          'nota': item.note.isNotEmpty ? item.note : null,
        });
      }
      
      // Preparar body del request
      final requestBody = {
        'tipoConsumo': order.tipoConsumo ?? 'EN_LUGAR', // 'EN_LUGAR' o 'PARA_RECOGER'
        'observaciones': order.observaciones ?? 'Pedido desde App Móvil',
        'items': itemsData,
      };
      
      debugPrint('[DEBUG SEND] Endpoint: POST /api/pedidos/con-items?membresiaId=$membresiaId&clubId=$clubId');
      debugPrint('[DEBUG SEND] Request body: $requestBody');
      
      // Enviar un solo POST con todos los items
      final response = await _client.post(
        '/pedidos/con-items',
        queryParameters: {
          'membresiaId': membresiaId,
          'clubId': clubId,
        },
        data: requestBody,
      );
      
      debugPrint('[DEBUG SEND] Respuesta del POST /pedidos/con-items - Status: ${response.statusCode}');
      debugPrint('[DEBUG SEND] Response body: ${response.data}');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('[DEBUG SEND] Pedido con múltiples items enviado exitosamente');
      } else if (response.statusCode == 401) {
        debugPrint('[DEBUG SEND] ERROR 401: No autenticado');
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        debugPrint('[DEBUG SEND] ERROR 403: Sin permisos');
        throw Exception('No tienes permisos para crear pedidos.');
      } else if (response.statusCode == 500) {
        debugPrint('[DEBUG SEND] ERROR 500: Error del servidor');
        throw Exception('Error del servidor. Por favor intenta más tarde.');
      } else {
        debugPrint('[DEBUG SEND] WARNING: Status code inesperado: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      debugPrint('[DEBUG SEND] DioException - Status: $statusCode');
      debugPrint('[DEBUG SEND] Error: ${e.message}');
      debugPrint('[DEBUG SEND] Response data: ${e.response?.data}');
      
      if (statusCode == 401) {
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (statusCode == 403) {
        throw Exception('No tienes permisos para crear pedidos.');
      } else if (statusCode == 500) {
        throw Exception('Error del servidor. Por favor intenta más tarde.');
      }
      
      final errorMessage = e.response?.data?['message'] ?? e.message ?? 'Error desconocido';
      debugPrint('[DEBUG SEND] Error enviando pedido - Status: $statusCode, Error: $errorMessage');
      throw Exception('Error enviando pedido: $errorMessage');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async {
    try {
      debugPrint('[DEBUG GET] Obteniendo pedidos para clubId: $clubId');
      debugPrint('[DEBUG GET] Endpoint: GET /api/pedidos/club/$clubId');
      debugPrint('[DEBUG GET] URL completa: ${_client.options.baseUrl}/pedidos/club/$clubId');
      
      final response = await _client.get('/pedidos/club/$clubId');
      
      debugPrint('[DEBUG GET] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG GET] Response body: ${response.data}');
      debugPrint('[DEBUG GET] Tipo de data: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        final dynamic data = response.data;
        List<Map<String, dynamic>> orders = [];
        
        if (data is List) {
          debugPrint('[DEBUG GET] Data es una Lista con ${data.length} elementos');
          if (data.isNotEmpty) {
            debugPrint('[DEBUG GET] Ejemplo del primer elemento: ${data.first}');
            // Verificar estructura del pedido
            final firstOrder = data.first as Map<String, dynamic>;
            debugPrint('[DEBUG GET] Keys del primer pedido: ${firstOrder.keys.toList()}');
            
            // Verificar si tiene clubId directo o a través de membresia
            if (firstOrder.containsKey('clubId')) {
              debugPrint('[DEBUG GET] El pedido tiene clubId directo: ${firstOrder['clubId']}');
            } else if (firstOrder.containsKey('membresia')) {
              final membresia = firstOrder['membresia'] as Map<String, dynamic>?;
              if (membresia != null && membresia.containsKey('clubId')) {
                debugPrint('[DEBUG GET] El pedido tiene clubId a través de membresia: ${membresia['clubId']}');
              }
            }
          }
          orders = data.cast<Map<String, dynamic>>();
        } else if (data is Map) {
          debugPrint('[DEBUG GET] Data es un Map con keys: ${data.keys.toList()}');
          if (data.containsKey('content') && data['content'] is List) {
            orders = (data['content'] as List).cast<Map<String, dynamic>>();
            debugPrint('[DEBUG GET] Pedidos en content: ${orders.length}');
          } else if (data.containsKey('data') && data['data'] is List) {
            orders = (data['data'] as List).cast<Map<String, dynamic>>();
            debugPrint('[DEBUG GET] Pedidos en data: ${orders.length}');
          } else {
            debugPrint('[DEBUG GET] WARNING: Data es Map pero no tiene content ni data. Keys: ${data.keys}');
            debugPrint('[DEBUG GET] Data completo: $data');
          }
        } else {
          debugPrint('[DEBUG GET] WARNING: Data tiene tipo inesperado: ${data.runtimeType}');
          debugPrint('[DEBUG GET] Data: $data');
        }
        
        debugPrint('[DEBUG GET] Total de pedidos obtenidos: ${orders.length}');
        if (orders.isNotEmpty) {
          debugPrint('[DEBUG GET] Estructura del primer pedido:');
          debugPrint('[DEBUG GET] Keys: ${orders.first.keys.toList()}');
          debugPrint('[DEBUG GET] Primer pedido completo: ${orders.first}');
        } else {
          debugPrint('[DEBUG GET] IMPORTANTE: No se encontraron pedidos para clubId: $clubId');
          debugPrint('[DEBUG GET] Esto puede significar:');
          debugPrint('[DEBUG GET]   1. No hay pedidos creados aún');
          debugPrint('[DEBUG GET]   2. Los pedidos se guardaron con un clubId diferente');
          debugPrint('[DEBUG GET]   3. El backend busca pedidos por membresia.clubId y no coincide');
        }
        
        return orders;
      } else if (response.statusCode == 401) {
        debugPrint('[DEBUG GET] ERROR 401: No autenticado');
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        debugPrint('[DEBUG GET] ERROR 403: Sin permisos');
        throw Exception('No tienes permisos para ver los pedidos de este club.');
      } else if (response.statusCode == 500) {
        debugPrint('[DEBUG GET] ERROR 500: Error del servidor');
        throw Exception('Error del servidor. Por favor intenta más tarde.');
      } else {
        debugPrint('[DEBUG GET] ERROR: Status code ${response.statusCode}');
        throw Exception('Error al obtener pedidos: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      debugPrint('[DEBUG GET] DioException - Status: $statusCode');
      debugPrint('[DEBUG GET] Response data: $responseData');
      
      if (statusCode == 401) {
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (statusCode == 403) {
        throw Exception('No tienes permisos para ver los pedidos de este club.');
      } else if (statusCode == 500) {
        throw Exception('Error del servidor. Por favor intenta más tarde.');
      }
      
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
      
      debugPrint('[DEBUG GET] Error obteniendo pedidos - Status: $statusCode, Error: $errorMessage');
      throw Exception('Error obteniendo pedidos: $errorMessage');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId) async {
    try {
      debugPrint('[DEBUG GET SOCIO] Obteniendo pedidos para membresiaId: $membresiaId');
      debugPrint('[DEBUG GET SOCIO] Endpoint: GET /api/pedidos/socio/$membresiaId');
      
      final response = await _client.get('/pedidos/socio/$membresiaId');
      
      debugPrint('[DEBUG GET SOCIO] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG GET SOCIO] Response body: ${response.data}');
      
      if (response.statusCode == 200) {
        final dynamic data = response.data;
        List<Map<String, dynamic>> orders = [];
        
        if (data is List) {
          orders = data.cast<Map<String, dynamic>>();
        } else if (data is Map) {
          if (data.containsKey('content') && data['content'] is List) {
            orders = (data['content'] as List).cast<Map<String, dynamic>>();
          } else if (data.containsKey('data') && data['data'] is List) {
            orders = (data['data'] as List).cast<Map<String, dynamic>>();
          }
        }
        
        debugPrint('[DEBUG GET SOCIO] Total de pedidos obtenidos: ${orders.length}');
        return orders;
      } else if (response.statusCode == 401) {
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        throw Exception('No tienes permisos para ver los pedidos.');
      } else {
        throw Exception('Error al obtener pedidos: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      debugPrint('[DEBUG GET SOCIO] DioException - Status: $statusCode');
      debugPrint('[DEBUG GET SOCIO] Error: ${e.message}');
      
      if (statusCode == 401) {
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (statusCode == 403) {
        throw Exception('No tienes permisos para ver los pedidos.');
      }
      
      final errorMessage = e.response?.data?['message'] ?? e.message ?? 'Error desconocido';
      throw Exception('Error obteniendo pedidos: $errorMessage');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() async {
    try {
      debugPrint('[DEBUG ALL] Obteniendo TODOS los pedidos (sin filtrar por club)');
      debugPrint('[DEBUG ALL] Endpoint: GET /pedidos');
      
      final response = await _client.get('/pedidos');
      
      debugPrint('[DEBUG ALL] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG ALL] Tipo de data: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        final dynamic data = response.data;
        List<Map<String, dynamic>> orders = [];
        
        if (data is List) {
          debugPrint('[DEBUG ALL] Data es una Lista con ${data.length} elementos');
          orders = data.cast<Map<String, dynamic>>();
        } else if (data is Map) {
          if (data.containsKey('content') && data['content'] is List) {
            orders = (data['content'] as List).cast<Map<String, dynamic>>();
          } else if (data.containsKey('data') && data['data'] is List) {
            orders = (data['data'] as List).cast<Map<String, dynamic>>();
          }
        }
        
        debugPrint('[DEBUG ALL] Total de pedidos en la BD: ${orders.length}');
        if (orders.isNotEmpty) {
          debugPrint('[DEBUG ALL] Primeros 3 pedidos:');
          for (int i = 0; i < orders.length && i < 3; i++) {
            final order = orders[i];
            debugPrint('[DEBUG ALL] Pedido ${i + 1}:');
            debugPrint('[DEBUG ALL]   ID: ${order['id']}');
            debugPrint('[DEBUG ALL]   Keys: ${order.keys.toList()}');
            if (order.containsKey('clubId')) {
              debugPrint('[DEBUG ALL]   clubId directo: ${order['clubId']}');
            }
            if (order.containsKey('membresia')) {
              final membresia = order['membresia'];
              if (membresia is Map) {
                debugPrint('[DEBUG ALL]   membresia.clubId: ${membresia['clubId']}');
                debugPrint('[DEBUG ALL]   membresia.id: ${membresia['id']}');
              }
            }
          }
        }
        
        return orders;
      } else {
        throw Exception('Error al obtener todos los pedidos: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('[DEBUG ALL] Error obteniendo todos los pedidos: ${e.message}');
      throw Exception('Error obteniendo todos los pedidos: ${e.message}');
    }
  }

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus, {int? tiempoEstimadoMinutos}) async {
    try {
      // Requisito backend: si estado=PREPARANDO, es obligatorio enviar tiempoEstimadoMinutos
      final normalizedStatus = newStatus.toUpperCase();
      if (normalizedStatus == 'PREPARANDO' && tiempoEstimadoMinutos == null) {
        throw Exception('Debes seleccionar un tiempo estimado antes de pasar el pedido a PREPARANDO.');
      }

      debugPrint('[DEBUG PATCH] Actualizando estado del pedido $pedidoId a $newStatus');
      final qpLog = normalizedStatus == 'PREPARANDO'
          ? 'estado=$newStatus&tiempoEstimadoMinutos=$tiempoEstimadoMinutos'
          : 'estado=$newStatus';
      debugPrint('[DEBUG PATCH] Endpoint: PATCH /api/pedidos/$pedidoId/estado?$qpLog');
      debugPrint('[DEBUG PATCH] URL completa: ${_client.options.baseUrl}/pedidos/$pedidoId/estado?$qpLog');
      
      final response = await _client.patch(
        '/pedidos/$pedidoId/estado',
        queryParameters: {
          'estado': newStatus,
          if (tiempoEstimadoMinutos != null) 'tiempoEstimadoMinutos': tiempoEstimadoMinutos,
        },
      );
      
      debugPrint('[DEBUG PATCH] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG PATCH] Response body: ${response.data}');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('[DEBUG PATCH] Estado actualizado exitosamente');
      } else if (response.statusCode == 401) {
        debugPrint('[DEBUG PATCH] ERROR 401: No autenticado');
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        debugPrint('[DEBUG PATCH] ERROR 403: Sin permisos');
        throw Exception('No tienes permisos para actualizar el estado del pedido.');
      } else if (response.statusCode == 500) {
        debugPrint('[DEBUG PATCH] ERROR 500: Error del servidor');
        throw Exception('Error del servidor. Por favor intenta más tarde.');
      } else {
        throw Exception('Error al actualizar estado: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      debugPrint('[DEBUG PATCH] DioException - Status: $statusCode');
      debugPrint('[DEBUG PATCH] Response data: ${e.response?.data}');
      
      if (statusCode == 401) {
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (statusCode == 403) {
        throw Exception('No tienes permisos para actualizar el estado del pedido.');
      } else if (statusCode == 500) {
        throw Exception('Error del servidor. Por favor intenta más tarde.');
      }
      
      String errorMessage = e.message ?? 'Error desconocido';
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        errorMessage = data['message'].toString();
      }
      debugPrint('[DEBUG PATCH] Error actualizando estado - Status: $statusCode, Error: $errorMessage');
      throw Exception('Error actualizando estado: $errorMessage');
    }
  }
}
