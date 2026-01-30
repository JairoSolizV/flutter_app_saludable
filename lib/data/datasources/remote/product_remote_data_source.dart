import 'package:dio/dio.dart';
import '../../../domain/entities/product.dart';

abstract class ProductRemoteDataSource {
  Future<List<Product>> getProducts({required int hubId, required int clubId});
  Future<List<Product>> getAvailableProductsByClub(int clubId); // Para socios: solo productos disponibles
  Future<void> createProduct(Product product, int clubId);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<void> toggleProductAvailability(int clubId, String productId);
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final Dio _client;

  ProductRemoteDataSourceImpl(this._client);

  @override
  Future<List<Product>> getProducts({required int hubId, required int clubId}) async {
    try {
      // Nuevo endpoint: GET /api/productos/hub/{hubId}?clubId={clubId}
      print('[DEBUG] Obteniendo productos - hubId: $hubId, clubId: $clubId');
      final response = await _client.get(
        '/productos/hub/$hubId', 
        queryParameters: {'clubId': clubId}
      );

      print('[DEBUG] Respuesta recibida - Status: ${response.statusCode}, Tipo de data: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        // Manejar diferentes formatos de respuesta del backend
        List<dynamic> data = [];
        if (response.data is List) {
          data = response.data as List<dynamic>;
        } else if (response.data is Map) {
          final Map<String, dynamic> responseMap = response.data as Map<String, dynamic>;
          if (responseMap.containsKey('content') && responseMap['content'] is List) {
            data = responseMap['content'] as List<dynamic>;
          } else if (responseMap.containsKey('data') && responseMap['data'] is List) {
            data = responseMap['data'] as List<dynamic>;
          }
        }
        
        print('[DEBUG] Total de productos en respuesta: ${data.length}');
        
        return data.map<Product>((json) {
           // Manejar el id correctamente: puede venir como int o String del backend
           final dynamic idValue = json['id'];
           final String productId = idValue is int ? idValue.toString() : (idValue?.toString() ?? '');
           
           // Debug: imprimir el ID del producto obtenido
           print('[DEBUG] Producto obtenido - ID original: $idValue, ID convertido: $productId, Nombre: ${json['nombre']}');
           
           // Manejar hubId correctamente: puede venir como int o null
           final dynamic hubIdValue = json['hubId'];
           final int? hubId = hubIdValue is int ? hubIdValue : (hubIdValue != null ? int.tryParse(hubIdValue.toString()) : null);
           
           // Manejar disponible: null significa que no hay relación, debe ser false por defecto
           final dynamic disponibleValue = json['disponible'];
           final bool available = disponibleValue == true || disponibleValue == 1;
           
           return Product(
             id: productId,
             name: json['nombre']?.toString() ?? 'Sin nombre',
             description: json['descripcion']?.toString() ?? '',
             price: 0.0, // Backend no envía precio aún
             category: 'General', 
             imageUrl: '', 
             hubId: hubId,
             active: json['activo'] == true || json['activo'] == 1,
             available: available, // false si es null, true/false según el valor
           );
        }).toList();
      } else {
        throw Exception('Error al cargar productos: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de red al cargar productos: ${e.message}');
    }
  }

  @override
  Future<List<Product>> getAvailableProductsByClub(int clubId) async {
    try {
      // Endpoint: GET /api/productos?clubId={clubId}
      // Este endpoint devuelve solo productos disponibles (disponible = true)
      print('[DEBUG] Obteniendo productos disponibles del club - clubId: $clubId');
      final response = await _client.get(
        '/productos',
        queryParameters: {'clubId': clubId}
      );

      print('[DEBUG] Respuesta recibida - Status: ${response.statusCode}, Tipo de data: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        // Manejar diferentes formatos de respuesta del backend
        List<dynamic> data = [];
        if (response.data is List) {
          data = response.data as List<dynamic>;
        } else if (response.data is Map) {
          final Map<String, dynamic> responseMap = response.data as Map<String, dynamic>;
          if (responseMap.containsKey('content') && responseMap['content'] is List) {
            data = responseMap['content'] as List<dynamic>;
          } else if (responseMap.containsKey('data') && responseMap['data'] is List) {
            data = responseMap['data'] as List<dynamic>;
          }
        }
        
        print('[DEBUG] Total de productos disponibles en respuesta: ${data.length}');
        
        return data.map<Product>((json) {
           // Manejar el id correctamente: puede venir como int o String del backend
           final dynamic idValue = json['id'];
           final String productId = idValue is int ? idValue.toString() : (idValue?.toString() ?? '');
           
           // Debug: imprimir el ID del producto obtenido
           print('[DEBUG] Producto disponible - ID: $productId, Nombre: ${json['nombre']}');
           
           // Manejar hubId correctamente: puede venir como int o null
           final dynamic hubIdValue = json['hubId'];
           final int? hubId = hubIdValue is int ? hubIdValue : (hubIdValue != null ? int.tryParse(hubIdValue.toString()) : null);
           
           return Product(
             id: productId,
             name: json['nombre']?.toString() ?? 'Sin nombre',
             description: json['descripcion']?.toString() ?? '',
             price: 0.0, // Backend no envía precio aún
             category: 'General', 
             imageUrl: '', 
             hubId: hubId,
             active: json['activo'] == true || json['activo'] == 1,
             available: true, // Estos productos siempre están disponibles (ya filtrados por el backend)
           );
        }).toList();
      } else {
        throw Exception('Error al cargar productos: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de red al cargar productos disponibles: ${e.message}');
    }
  }

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {
    try {
      // Convertir productId de String a int para el backend
      final int productIdInt = int.parse(productId);
      
      // Debug: imprimir los valores que se están enviando
      print('[DEBUG] Toggle producto - clubId: $clubId, productId: $productId (int: $productIdInt)');
      
      // Endpoint: PATCH /api/clubes/{clubId}/productos/{productoId}/toggle
      final response = await _client.patch('/clubes/$clubId/productos/$productIdInt/toggle');
      
      // Debug: imprimir respuesta exitosa
      print('[DEBUG] Toggle exitoso - Response: ${response.statusCode}');
    } on DioException catch (e) {
      // Mejorar mensaje de error con más detalles
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      
      print('[DEBUG] Error en toggle - Status: $statusCode, Data: $responseData');
      
      // Extraer mensaje de error del backend (ApiResponse tiene message en la raíz)
      String errorMessage = 'Error desconocido';
      if (responseData is Map) {
        // El backend devuelve ApiResponse con estructura: { success: false, message: "...", data: null }
        errorMessage = responseData['message']?.toString() ?? 
                      responseData['error']?.toString() ?? 
                      responseData['data']?.toString() ??
                      e.message ?? 'Error desconocido';
      } else if (responseData is String) {
        errorMessage = responseData;
      } else {
        errorMessage = e.message ?? 'Error desconocido';
      }
      
      print('[DEBUG] Mensaje de error extraído: $errorMessage');
      
      if (statusCode == 403) {
        throw Exception('Error cambiando disponibilidad: No tienes permisos para modificar este producto. Verifica que seas el anfitrión del club.');
      } else if (statusCode == 401) {
        throw Exception('Error cambiando disponibilidad: Tu sesión ha expirado. Por favor, inicia sesión nuevamente.');
      } else if (statusCode == 404) {
        // El mensaje del backend ya dice "Producto no encontrado con id: X"
        throw Exception('Error cambiando disponibilidad: $errorMessage');
      } else if (statusCode == 400) {
        throw Exception('Error cambiando disponibilidad: Solicitud inválida. $errorMessage');
      } else {
        throw Exception('Error cambiando disponibilidad: $errorMessage');
      }
    } on FormatException catch (e) {
      throw Exception('Error cambiando disponibilidad: ID de producto inválido: $productId');
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
    } on DioException catch (e) {
      throw Exception('Error al crear producto: ${e.response?.data['message'] ?? e.message}');
    }
  }

  @override
  Future<void> updateProduct(Product product) async {
    try {
      final data = {
        'nombre': product.name,
        'descripcion': product.description,
        'activo': product.active,
      };
      // Endpoint PUT /api/productos/{id}
      await _client.put('/productos/${product.id}', data: data);
    } on DioException catch (e) {
       throw Exception('Error al actualizar producto: ${e.response?.data['message'] ?? e.message}');
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    try {
      // Usaremos patch/desactivar o delete según backend. Asumimos delete o desactivar.
      // El usuario mencionó "desactivar" en un paso anterior mío, pero la API standard suele ser DELETE.
      // Voy a usar DELETE y si falla manejo error. O mejor, uso el endpoint de desactivar si sé que existe.
      // En el paso 758 puse: await _client.patch('/productos/$id/desactivar');
      // Voy a mantener eso.
      await _client.patch('/productos/$id/desactivar');
    } on DioException catch (e) {
      // Si falla ruta no encontrada, intentamos DELETE estándar como fallback
      if (e.response?.statusCode == 404) {
          try {
             await _client.delete('/productos/$id');
             return;
          } catch (_) {}
      }
      throw Exception('Error al eliminar producto: ${e.response?.data['message'] ?? e.message}');
    }
  }
}
