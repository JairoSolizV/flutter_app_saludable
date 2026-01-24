import 'package:dio/dio.dart';
import '../../../domain/entities/product.dart';

abstract class ProductRemoteDataSource {
  Future<List<Product>> getProducts({required int hubId, required int clubId});
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
      final response = await _client.get(
        '/productos/hub/$hubId', 
        queryParameters: {'clubId': clubId}
      );

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
        
        return data.map<Product>((json) {
           // Manejar el id correctamente: puede venir como int o String del backend
           final dynamic idValue = json['id'];
           final String productId = idValue is int ? idValue.toString() : (idValue?.toString() ?? '');
           
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
             available: json['disponible'] == true || json['disponible'] == 1,
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
  Future<void> toggleProductAvailability(int clubId, String productId) async {
    try {
      // Convertir productId de String a int para el backend
      final int productIdInt = int.parse(productId);
      // Endpoint: PATCH /api/clubes/{clubId}/productos/{productoId}/toggle
      await _client.patch('/clubes/$clubId/productos/$productIdInt/toggle');
    } on DioException catch (e) {
      // Mejorar mensaje de error con más detalles
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['message'] ?? e.message ?? 'Error desconocido';
      
      if (statusCode == 403) {
        throw Exception('Error cambiando disponibilidad: No tienes permisos para modificar este producto. Verifica que seas el anfitrión del club.');
      } else if (statusCode == 401) {
        throw Exception('Error cambiando disponibilidad: Tu sesión ha expirado. Por favor, inicia sesión nuevamente.');
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
