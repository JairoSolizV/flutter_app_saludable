import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/throw_app_error.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/product.dart';

abstract class ProductRemoteDataSource {
  Future<List<Product>> getProducts({required int hubId, required int clubId});
  Future<List<Product>> getAvailableProductsByClub(int clubId);
  Future<void> createProduct(Product product, int clubId);

  /// Sube una imagen y devuelve la URL (imagenUrl) para el producto.
  Future<String> uploadProductImage(File imageFile);

  /// Enviar propuesta de producto. imagenUrl opcional (foto subida o URL).
  /// [optionGroups] se envía solo si hay definición; no se manda null.
  Future<void> createProductProposal({
    required int hubId,
    required String nombre,
    required String descripcion,
    required String ingredientes,
    required int puntosValor,
    String? imagenUrl,
    List<ProductOptionGroup>? optionGroups,
  });
  Future<void> updateProduct(Product product);

  /// PATCH /productos/{id}/reenviar — solo LOCAL RECHAZADO del propietario.
  Future<Product> reenviarProducto(String productId);

  /// Legacy. El anfitrión no desactiva productos globalmente.
  /// No llama PATCH /productos/{id}/desactivar ni DELETE.
  Future<void> deleteProduct(String id);
  Future<void> toggleProductAvailability(int clubId, String productId);
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final Dio _client;

  ProductRemoteDataSourceImpl(this._client);

  @override
  Future<List<Product>> getProducts(
      {required int hubId, required int clubId}) async {
    try {
      // Nuevos endpoints separados para Globales y Locales
      debugPrint(
          '[DEBUG PRODUCTOS] Obteniendo productos separados por tipo para el club $clubId');

      final globalResponseFuture = _client.get('/productos',
          queryParameters: {'clubId': clubId, 'tipo': 'GLOBAL'});
      final localResponseFuture = _client.get('/productos',
          queryParameters: {'clubId': clubId, 'tipo': 'LOCAL'});

      final responses =
          await Future.wait([globalResponseFuture, localResponseFuture]);
      final globalResponse = responses[0];
      final localResponse = responses[1];

      if (globalResponse.statusCode == 200 && localResponse.statusCode == 200) {
        // Función para extraer lista de response data
        List<dynamic> extractData(Response res) {
          debugPrint(
              '[DEBUG PRODUCTOS] Extrayendo data de repuesta. Tipo real: ${res.data.runtimeType}\nContenido bruto: ${res.data}');
          if (res.data is List) {
            return res.data as List<dynamic>;
          } else if (res.data is Map) {
            final Map<String, dynamic> responseMap =
                res.data as Map<String, dynamic>;
            if (responseMap.containsKey('content') &&
                responseMap['content'] is List) {
              return responseMap['content'] as List<dynamic>;
            } else if (responseMap.containsKey('data') &&
                responseMap['data'] is List) {
              return responseMap['data'] as List<dynamic>;
            } else if (responseMap.containsKey('productos') &&
                responseMap['productos'] is List) {
              return responseMap['productos'] as List<dynamic>;
            }
          }
          return [];
        }

        debugPrint('[DEBUG PRODUCTOS] Extrayendo datos globales...');
        final globalDataList = extractData(globalResponse);
        debugPrint('[DEBUG PRODUCTOS] Global length: ${globalDataList.length}');

        debugPrint('[DEBUG PRODUCTOS] Extrayendo datos locales...');
        final localDataList = extractData(localResponse);
        debugPrint('[DEBUG PRODUCTOS] Local length: ${localDataList.length}');

        final combinedProducts = <Product>[];

        Product parseProduct(dynamic json, String defaultTipo) {
          // Manejar el id correctamente: puede venir como int o String del backend
          final dynamic idValue = json['id'];
          final String productId =
              idValue is int ? idValue.toString() : (idValue?.toString() ?? '');

          // Manejar hubId correctamente: puede venir como int o null
          final dynamic hubIdValue = json['hubId'];
          final int? parsedHubId = hubIdValue is int
              ? hubIdValue
              : (hubIdValue != null
                  ? int.tryParse(hubIdValue.toString())
                  : null);

          // Manejar disponible: null significa que no hay relación, debe ser false por defecto
          final dynamic disponibleValue = json['disponible'];
          final bool available =
              disponibleValue == true || disponibleValue == 1;

          // Obtener inteligentemente el clubCreadorId y parsearlo a int
          final dynamic rawClubCreadorId = json['clubCreadorId'] ??
              json['club_creador_id'] ??
              json['clubId'] ??
              json['club_id'];
          final int? parsedClubCreadorId = rawClubCreadorId != null
              ? (rawClubCreadorId is int
                  ? rawClubCreadorId
                  : int.tryParse(rawClubCreadorId.toString()))
              : null;

          final String imageUrl = json['imagenUrl']?.toString() ??
              json['image_url']?.toString() ??
              '';
          final int puntosValor = json['puntosValor'] is int
              ? json['puntosValor'] as int
              : (int.tryParse(json['puntosValor']?.toString() ?? '0') ?? 0);
          return Product(
            id: productId,
            name: json['nombre']?.toString() ?? 'Sin nombre',
            description: json['descripcion']?.toString() ?? '',
            price: 0.0,
            puntosValor: puntosValor,
            category: 'General',
            imageUrl: imageUrl,
            hubId: parsedHubId,
            clubCreadorId: parsedClubCreadorId,
            tipo: json['tipo']?.toString().toUpperCase() ?? defaultTipo,
            estadoAprobacion:
                json['estadoAprobacion']?.toString().toUpperCase() ??
                    'APROBADO',
            active: json['activo'] == true || json['activo'] == 1,
            available: available,
            ingredientes: _optionalString(json['ingredientes']),
            comentarioRevision: _optionalString(json['comentarioRevision']),
            revisadoPorUsuarioId: _optionalInt(json['revisadoPorUsuarioId']),
            revisadoPorNombre: _optionalString(json['revisadoPorNombre']),
            revisadoAt: _optionalDateTime(json['revisadoAt']),
            optionGroups: ProductOptionGroup.listFromJson(json['gruposOpciones']),
          );
        }

        for (var json in globalDataList) {
          combinedProducts.add(parseProduct(json, 'GLOBAL'));
        }
        for (var json in localDataList) {
          combinedProducts.add(parseProduct(json, 'LOCAL'));
        }

        return combinedProducts;
      } else {
        throw ServerException('Error al cargar productos');
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error de red al cargar productos', stackTrace: st);
    }
  }

  @override
  Future<List<Product>> getAvailableProductsByClub(int clubId) async {
    try {
      // Nuevo endpoint validado para socios: GET /api/productos?clubId={id}
      // El backend devuelve automáticamente:
      // - Productos globales habilitados
      // - Productos locales del club en estado APROBADO y disponibles
      debugPrint(
          '[DEBUG PRODUCTOS] Obteniendo productos disponibles del club - clubId: $clubId');
      debugPrint(
          '[DEBUG PRODUCTOS] Endpoint: GET /api/productos?clubId=$clubId');
      debugPrint(
          '[DEBUG PRODUCTOS] URL completa: ${_client.options.baseUrl}/productos?clubId=$clubId');

      final response = await _client.get(
        '/productos?clubId=$clubId',
      );

      debugPrint(
          '[DEBUG PRODUCTOS] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG PRODUCTOS] Response body: ${response.data}');
      debugPrint(
          '[DEBUG PRODUCTOS] Tipo de data: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        // Manejar diferentes formatos de respuesta del backend
        List<dynamic> data = [];
        if (response.data is List) {
          data = response.data as List<dynamic>;
        } else if (response.data is Map) {
          final Map<String, dynamic> responseMap =
              response.data as Map<String, dynamic>;
          if (responseMap.containsKey('content') &&
              responseMap['content'] is List) {
            data = responseMap['content'] as List<dynamic>;
          } else if (responseMap.containsKey('data') &&
              responseMap['data'] is List) {
            data = responseMap['data'] as List<dynamic>;
          }
        }

        debugPrint(
            '[DEBUG PRODUCTOS] Total de productos disponibles en respuesta: ${data.length}');

        return data.map<Product>((json) {
          // Manejar el id correctamente: puede venir como int o String del backend
          final dynamic idValue = json['id'];
          final String productId =
              idValue is int ? idValue.toString() : (idValue?.toString() ?? '');

          // Debug: imprimir el ID del producto obtenido
          debugPrint(
              '[DEBUG PRODUCTOS] Producto disponible - ID: $productId, Nombre: ${json['nombre']}');

          // Manejar hubId correctamente: puede venir como int o null
          final dynamic hubIdValue = json['hubId'];
          final int? hubId = hubIdValue is int
              ? hubIdValue
              : (hubIdValue != null
                  ? int.tryParse(hubIdValue.toString())
                  : null);

          // Manejar disponible: si viene false, es false. Si viene null, true por defecto para este endpoint
          final dynamic disponibleValue = json['disponible'];
          final bool isAvailable =
              disponibleValue == false || disponibleValue == 0 ? false : true;

          // Obtener inteligentemente el clubCreadorId y parsearlo a int
          final dynamic rawClubCreadorId = json['clubCreadorId'] ??
              json['club_creador_id'] ??
              json['clubId'] ??
              json['club_id'];
          final int? parsedClubCreadorId = rawClubCreadorId != null
              ? (rawClubCreadorId is int
                  ? rawClubCreadorId
                  : int.tryParse(rawClubCreadorId.toString()))
              : null;
          final String imageUrl = json['imagenUrl']?.toString() ??
              json['image_url']?.toString() ??
              '';
          final int puntosValor = json['puntosValor'] is int
              ? json['puntosValor'] as int
              : (int.tryParse(json['puntosValor']?.toString() ?? '0') ?? 0);
          final String tipo =
              json['tipo']?.toString().toUpperCase() ?? 'GLOBAL';
          final String estadoAprobacion =
              json['estadoAprobacion']?.toString().toUpperCase() ?? 'APROBADO';

          return Product(
            id: productId,
            name: json['nombre']?.toString() ?? 'Sin nombre',
            description: json['descripcion']?.toString() ?? '',
            price: 0.0,
            puntosValor: puntosValor,
            category: 'General',
            imageUrl: imageUrl,
            hubId: hubId,
            clubCreadorId: parsedClubCreadorId,
            tipo: tipo,
            estadoAprobacion: estadoAprobacion,
            active: json['activo'] == true || json['activo'] == 1,
            available: isAvailable,
          );
        }).toList();
      } else if (response.statusCode == 401) {
        debugPrint('[DEBUG PRODUCTOS] ERROR 401: No autenticado');
        throw UnauthorizedException(
            'No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        debugPrint('[DEBUG PRODUCTOS] ERROR 403: Sin permisos');
        throw ForbiddenException('No tienes permisos para ver los productos.');
      } else if (response.statusCode == 500) {
        debugPrint('[DEBUG PRODUCTOS] ERROR 500: Error del servidor');
        throw ServerException(
            'Error del servidor. Por favor intenta más tarde.',
            statusCode: 500);
      } else {
        debugPrint(
            '[DEBUG PRODUCTOS] ERROR: Status code ${response.statusCode}');
        throw ServerException('Error al cargar productos',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error de red al cargar productos disponibles',
          stackTrace: st);
    }
  }

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {
    try {
      // Convertir productId de String a int para el backend
      final int productIdInt = int.parse(productId);

      // Debug: imprimir los valores que se están enviando
      debugPrint(
          '[DEBUG PRODUCTOS] Toggle producto - clubId: $clubId, productId: $productId (int: $productIdInt)');

      // Endpoint: PATCH /api/clubes/{clubId}/productos/{productoId}/toggle
      final response =
          await _client.patch('/clubes/$clubId/productos/$productIdInt/toggle');

      // Debug: imprimir respuesta exitosa
      debugPrint(
          '[DEBUG PRODUCTOS] Toggle exitoso - Response: ${response.statusCode}');
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error cambiando disponibilidad', stackTrace: st);
    } on FormatException {
      throw ValidationException(
          'Error cambiando disponibilidad: ID de producto inválido');
    }
  }

  @override
  Future<void> createProduct(Product product, int clubId) async {
    try {
      final data = {
        'nombre': product.name,
        'descripcion': product.description,
        'activo': product.active,
      };

      await _client.post(
        '/productos',
        queryParameters: {'clubId': clubId},
        data: data,
      );
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error en productos', stackTrace: st);
    }
  }

  @override
  @override
  Future<String> uploadProductImage(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split(RegExp(r'[/\\]')).last,
        ),
      });
      final response = await _client.post(
        '/productos/subir-imagen',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Accept': 'application/json'},
        ),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final path = response.data['imagenUrl']?.toString() ?? '';
        if (path.isEmpty) throw ServerException('No se recibió URL de imagen');
        final baseUri = Uri.parse(_client.options.baseUrl);
        return '${baseUri.origin}$path';
      }
      throw ServerException('Error al subir la imagen',
          statusCode: response.statusCode);
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error de red al subir imagen', stackTrace: st);
    }
  }

  @override
  Future<void> createProductProposal({
    required int hubId,
    required String nombre,
    required String descripcion,
    required String ingredientes,
    required int puntosValor,
    String? imagenUrl,
    List<ProductOptionGroup>? optionGroups,
  }) async {
    try {
      final data = <String, dynamic>{
        'hubId': hubId,
        'nombre': nombre,
        'descripcion': descripcion,
        'ingredientes': ingredientes,
        'puntosValor': puntosValor,
        'activo': true,
      };
      if (imagenUrl != null && imagenUrl.isNotEmpty) {
        data['imagenUrl'] = imagenUrl;
      }
      if (optionGroups != null && optionGroups.isNotEmpty) {
        data['gruposOpciones'] =
            optionGroups.map((g) => g.toApiMap()).toList();
      }

      debugPrint('[DEBUG PRODUCTOS] Enviando propuesta de producto: $data');
      debugPrint('[DEBUG PRODUCTOS] Endpoint: POST /api/productos');

      final response = await _client.post(
        '/productos',
        data: data,
      );

      debugPrint(
          '[DEBUG PRODUCTOS] Respuesta propuesta producto - Status: ${response.statusCode}');
      debugPrint('[DEBUG PRODUCTOS] Body: ${response.data}');

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw ServerException('Error al enviar propuesta de producto',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error al enviar propuesta de producto', stackTrace: st);
    }
  }

  @override
  Future<void> updateProduct(Product product) async {
    try {
      final data = <String, dynamic>{
        'nombre': product.name,
        'descripcion': product.description,
        'puntosValor': product.puntosValor,
        'activo': product.active,
      };
      if (product.ingredientes != null) {
        data['ingredientes'] = product.ingredientes;
      }
      if (product.imageUrl.isNotEmpty) {
        data['imagenUrl'] = product.imageUrl;
      }
      if (product.optionGroups != null) {
        data['gruposOpciones'] =
            product.optionGroups!.map((g) => g.toApiMap()).toList();
      }
      // Endpoint PUT /api/productos/{id}
      await _client.put('/productos/${product.id}', data: data);
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error en productos', stackTrace: st);
    }
  }

  @override
  Future<Product> reenviarProducto(String productId) async {
    try {
      final response = await _client.patch('/productos/$productId/reenviar');
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map) {
          return Product.fromMap(Map<String, dynamic>.from(response.data));
        }
        return Product(
          id: productId,
          name: '',
          description: '',
          tipo: 'LOCAL',
          estadoAprobacion: 'PENDIENTE',
        );
      }
      throw ServerException(
        'Error al reenviar el producto a revisión',
        statusCode: response.statusCode,
      );
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error al reenviar el producto a revisión', stackTrace: st);
    }
  }

  static String? _optionalString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _optionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime? _optionalDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  Future<void> deleteProduct(String id) async {
    throw UnsupportedError(
      'El anfitrión no puede desactivar ni borrar productos de forma global. '
      'Usa PATCH /clubes/{clubId}/productos/{productoId}/toggle.',
    );
  }
}
