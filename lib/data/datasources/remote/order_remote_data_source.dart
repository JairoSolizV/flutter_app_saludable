import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/throw_app_error.dart';
import 'package:flutter/foundation.dart';
import '../../../core/pagination/paged_result.dart';
import '../../../domain/entities/order_entity.dart';

abstract class OrderRemoteDataSource {
  Future<void> sendOrder(OrderEntity order, List<OrderItem> items);
  Future<void> createCounterSale({
    required int clubId,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
  });
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId);
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId);

  /// Versión paginada de [getOrdersByClub].
  /// Endpoint: GET /pedidos/club/{clubId}/paginados?page&size&estado&desde&hasta
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(
    int clubId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  });

  /// Versión paginada de [getOrdersBySocio].
  /// Endpoint: GET /pedidos/socio/{membresiaId}/paginados?page&size&estado&desde&hasta
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(
    int membresiaId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  });

  Future<void> updateOrderStatus(int pedidoId, String newStatus,
      {int? estimatedTime});
  Future<List<Map<String, dynamic>>>
      getAllOrders(); // Método temporal para debug
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final Dio _client;

  OrderRemoteDataSourceImpl(this._client);

  String _extractBackendMessage(dynamic data,
      {String fallback = 'Error desconocido'}) {
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      if (message != null && message.trim().isNotEmpty) return message;
      final error = data['error']?.toString();
      if (error != null && error.trim().isNotEmpty) return error;
    } else if (data is String && data.trim().isNotEmpty) {
      return data;
    }
    return fallback;
  }

  @override
  Future<void> createCounterSale({
    required int clubId,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('Debes agregar al menos un producto al ticket.');
    }

    final requestBody = <String, dynamic>{
      'clubId': clubId,
      'socioCodigo': (socioCodigo == null || socioCodigo.trim().isEmpty)
          ? null
          : socioCodigo.trim(),
      'tipoConsumo': (tipoConsumo == null || tipoConsumo.trim().isEmpty)
          ? 'EN_LUGAR'
          : tipoConsumo,
      'observaciones': observaciones?.trim(),
      'items': items,
    };

    try {
      debugPrint(
          '[DEBUG COUNTER] POST /api/pedidos/mostrador body: $requestBody');
      final response =
          await _client.post('/pedidos/mostrador', data: requestBody);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }
      final message = _extractBackendMessage(response.data,
          fallback: 'No se pudo registrar la venta');
      throw ServerException(message, statusCode: response.statusCode);
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error en pedidos', stackTrace: st);
    }
  }

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

    debugPrint(
        '[DEBUG SEND] Enviando pedido con múltiples items - membresiaId: $membresiaId, clubId: $clubId, items: ${items.length}');

    try {
      // Preparar items para el backend
      final List<Map<String, dynamic>> itemsData = [];
      for (var item in items) {
        final int productoId = int.parse(item.productId);
        final itemMap = <String, dynamic>{
          'productoId': productoId,
          'cantidad': item.quantity,
          'nota': item.note,
          'opciones': item.options.map((o) => o.toApiMap()).toList(),
        };
        if (item.comboId != null) {
          itemMap['comboId'] = item.comboId;
        }
        itemsData.add(itemMap);
      }

      // Preparar body del request
      final requestBody = {
        'tipoConsumo':
            order.tipoConsumo ?? 'EN_LUGAR', // 'EN_LUGAR' o 'PARA_RECOGER'
        'observaciones': order.observaciones ?? 'Pedido desde App Móvil',
        'items': itemsData,
      };

      debugPrint(
          '[DEBUG SEND] Endpoint: POST /api/pedidos/con-items?membresiaId=$membresiaId&clubId=$clubId');
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

      debugPrint(
          '[DEBUG SEND] Respuesta del POST /pedidos/con-items - Status: ${response.statusCode}');
      debugPrint('[DEBUG SEND] Response body: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint(
            '[DEBUG SEND] Pedido con múltiples items enviado exitosamente');
      } else if (response.statusCode == 401) {
        debugPrint('[DEBUG SEND] ERROR 401: No autenticado');
        throw UnauthorizedException(
            'No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        debugPrint('[DEBUG SEND] ERROR 403: Sin permisos');
        throw ForbiddenException('No tienes permisos para crear pedidos.');
      } else if (response.statusCode == 400) {
        final message = _extractBackendMessage(response.data,
            fallback: 'No se pudo crear el pedido');
        debugPrint('[DEBUG SEND] ERROR 400: $message');
        throw ValidationException(message);
      } else if (response.statusCode == 500) {
        debugPrint('[DEBUG SEND] ERROR 500: Error del servidor');
        throw ServerException(
            'Error del servidor. Por favor intenta más tarde.',
            statusCode: 500);
      } else {
        debugPrint(
            '[DEBUG SEND] ERROR: Status code inesperado: ${response.statusCode}');
        throw ServerException(
          _extractBackendMessage(response.data,
              fallback: 'Error al crear el pedido'),
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error enviando pedido', stackTrace: st);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async {
    try {
      debugPrint('[DEBUG GET] Obteniendo pedidos para clubId: $clubId');
      debugPrint('[DEBUG GET] Endpoint: GET /api/pedidos/club/$clubId');
      debugPrint(
          '[DEBUG GET] URL completa: ${_client.options.baseUrl}/pedidos/club/$clubId');

      final response = await _client.get('/pedidos/club/$clubId');

      debugPrint(
          '[DEBUG GET] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG GET] Response body: ${response.data}');
      debugPrint('[DEBUG GET] Tipo de data: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        final dynamic data = response.data;
        List<Map<String, dynamic>> orders = [];

        if (data is List) {
          debugPrint(
              '[DEBUG GET] Data es una Lista con ${data.length} elementos');
          if (data.isNotEmpty) {
            debugPrint(
                '[DEBUG GET] Ejemplo del primer elemento: ${data.first}');
            // Verificar estructura del pedido
            final firstOrder = data.first as Map<String, dynamic>;
            debugPrint(
                '[DEBUG GET] Keys del primer pedido: ${firstOrder.keys.toList()}');

            // Verificar si tiene clubId directo o a través de membresia
            if (firstOrder.containsKey('clubId')) {
              debugPrint(
                  '[DEBUG GET] El pedido tiene clubId directo: ${firstOrder['clubId']}');
            } else if (firstOrder.containsKey('membresia')) {
              final membresia =
                  firstOrder['membresia'] as Map<String, dynamic>?;
              if (membresia != null && membresia.containsKey('clubId')) {
                debugPrint(
                    '[DEBUG GET] El pedido tiene clubId a través de membresia: ${membresia['clubId']}');
              }
            }
          }
          orders = data.cast<Map<String, dynamic>>();
        } else if (data is Map) {
          debugPrint(
              '[DEBUG GET] Data es un Map con keys: ${data.keys.toList()}');
          if (data.containsKey('content') && data['content'] is List) {
            orders = (data['content'] as List).cast<Map<String, dynamic>>();
            debugPrint('[DEBUG GET] Pedidos en content: ${orders.length}');
          } else if (data.containsKey('data') && data['data'] is List) {
            orders = (data['data'] as List).cast<Map<String, dynamic>>();
            debugPrint('[DEBUG GET] Pedidos en data: ${orders.length}');
          } else {
            debugPrint(
                '[DEBUG GET] WARNING: Data es Map pero no tiene content ni data. Keys: ${data.keys}');
            debugPrint('[DEBUG GET] Data completo: $data');
          }
        } else {
          debugPrint(
              '[DEBUG GET] WARNING: Data tiene tipo inesperado: ${data.runtimeType}');
          debugPrint('[DEBUG GET] Data: $data');
        }

        debugPrint('[DEBUG GET] Total de pedidos obtenidos: ${orders.length}');
        if (orders.isNotEmpty) {
          debugPrint('[DEBUG GET] Estructura del primer pedido:');
          debugPrint('[DEBUG GET] Keys: ${orders.first.keys.toList()}');
          debugPrint('[DEBUG GET] Primer pedido completo: ${orders.first}');
        } else {
          debugPrint(
              '[DEBUG GET] IMPORTANTE: No se encontraron pedidos para clubId: $clubId');
          debugPrint('[DEBUG GET] Esto puede significar:');
          debugPrint('[DEBUG GET]   1. No hay pedidos creados aún');
          debugPrint(
              '[DEBUG GET]   2. Los pedidos se guardaron con un clubId diferente');
          debugPrint(
              '[DEBUG GET]   3. El backend busca pedidos por membresia.clubId y no coincide');
        }

        return orders;
      } else if (response.statusCode == 401) {
        debugPrint('[DEBUG GET] ERROR 401: No autenticado');
        throw UnauthorizedException(
            'No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        debugPrint('[DEBUG GET] ERROR 403: Sin permisos');
        throw ForbiddenException(
            'No tienes permisos para ver los pedidos de este club.');
      } else if (response.statusCode == 500) {
        debugPrint('[DEBUG GET] ERROR 500: Error del servidor');
        throw ServerException(
            'Error del servidor. Por favor intenta más tarde.',
            statusCode: 500);
      } else {
        debugPrint('[DEBUG GET] ERROR: Status code ${response.statusCode}');
        throw ServerException('Error al obtener pedidos',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error obteniendo pedidos', stackTrace: st);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId) async {
    try {
      debugPrint(
          '[DEBUG GET SOCIO] Obteniendo pedidos para membresiaId: $membresiaId');
      debugPrint(
          '[DEBUG GET SOCIO] Endpoint: GET /api/pedidos/socio/$membresiaId');

      final response = await _client.get('/pedidos/socio/$membresiaId');

      debugPrint(
          '[DEBUG GET SOCIO] Respuesta recibida - Status: ${response.statusCode}');
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

        debugPrint(
            '[DEBUG GET SOCIO] Total de pedidos obtenidos: ${orders.length}');
        return orders;
      } else if (response.statusCode == 401) {
        throw UnauthorizedException(
            'No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        throw ForbiddenException('No tienes permisos para ver los pedidos.');
      } else {
        throw ServerException('Error al obtener pedidos',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error obteniendo pedidos', stackTrace: st);
    }
  }

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(
    int clubId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) async {
    try {
      final response = await _client.get(
        '/pedidos/club/$clubId/paginados',
        queryParameters: {
          'page': page,
          'size': size,
          if (estado != null && estado.isNotEmpty) 'estado': estado,
          if (desde != null && desde.isNotEmpty) 'desde': desde,
          if (hasta != null && hasta.isNotEmpty) 'hasta': hasta,
        },
      );

      final dynamic data = response.data;
      if (data is! Map) {
        throw ServerException(
          'Respuesta inesperada al obtener pedidos paginados del club',
        );
      }
      return PagedResult<Map<String, dynamic>>.fromJson(
        Map<String, dynamic>.from(data),
        (item) => item,
      );
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error obteniendo pedidos paginados', stackTrace: st);
    }
  }

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(
    int membresiaId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) async {
    try {
      final response = await _client.get(
        '/pedidos/socio/$membresiaId/paginados',
        queryParameters: {
          'page': page,
          'size': size,
          if (estado != null && estado.isNotEmpty) 'estado': estado,
          if (desde != null && desde.isNotEmpty) 'desde': desde,
          if (hasta != null && hasta.isNotEmpty) 'hasta': hasta,
        },
      );

      final dynamic data = response.data;
      if (data is! Map) {
        throw ServerException(
          'Respuesta inesperada al obtener pedidos paginados del socio',
        );
      }
      return PagedResult<Map<String, dynamic>>.fromJson(
        Map<String, dynamic>.from(data),
        (item) => item,
      );
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error obteniendo pedidos paginados', stackTrace: st);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() async {
    try {
      debugPrint(
          '[DEBUG ALL] Obteniendo TODOS los pedidos (sin filtrar por club)');
      debugPrint('[DEBUG ALL] Endpoint: GET /pedidos');

      final response = await _client.get('/pedidos');

      debugPrint(
          '[DEBUG ALL] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG ALL] Tipo de data: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        final dynamic data = response.data;
        List<Map<String, dynamic>> orders = [];

        if (data is List) {
          debugPrint(
              '[DEBUG ALL] Data es una Lista con ${data.length} elementos');
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
                debugPrint(
                    '[DEBUG ALL]   membresia.clubId: ${membresia['clubId']}');
                debugPrint('[DEBUG ALL]   membresia.id: ${membresia['id']}');
              }
            }
          }
        }

        return orders;
      } else {
        throw ServerException('Error al obtener todos los pedidos',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error obteniendo todos los pedidos', stackTrace: st);
    }
  }

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus,
      {int? estimatedTime}) async {
    try {
      debugPrint(
          '[DEBUG PATCH] Actualizando estado del pedido $pedidoId a $newStatus');

      final Map<String, dynamic> queryParams = {'estado': newStatus};
      final Map<String, dynamic> bodyData = {};

      if (estimatedTime != null) {
        queryParams['tiempoEstimadoMinutos'] = estimatedTime;
        bodyData['tiempoEstimadoMinutos'] = estimatedTime;

        // Also add the snake_case version just in case, since the error explicitly asked for it
        queryParams['tiempo_estimado_minutos'] = estimatedTime;
        bodyData['tiempo_estimado_minutos'] = estimatedTime;
      }

      debugPrint(
          '[DEBUG PATCH] Endpoint: PATCH /api/pedidos/$pedidoId/estado con params: $queryParams y body: $bodyData');

      final response = await _client.patch(
        '/pedidos/$pedidoId/estado',
        queryParameters: queryParams,
        data: bodyData.isNotEmpty ? bodyData : null,
      );

      debugPrint(
          '[DEBUG PATCH] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG PATCH] Response body: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('[DEBUG PATCH] Estado actualizado exitosamente');
      } else if (response.statusCode == 401) {
        debugPrint('[DEBUG PATCH] ERROR 401: No autenticado');
        throw UnauthorizedException(
            'No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        debugPrint('[DEBUG PATCH] ERROR 403: Sin permisos');
        throw ForbiddenException(
            'No tienes permisos para actualizar el estado del pedido.');
      } else if (response.statusCode == 500) {
        debugPrint('[DEBUG PATCH] ERROR 500: Error del servidor');
        throw ServerException(
            'Error del servidor. Por favor intenta más tarde.',
            statusCode: 500);
      } else {
        throw ServerException('Error al actualizar estado',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error actualizando estado', stackTrace: st);
    }
  }
}
