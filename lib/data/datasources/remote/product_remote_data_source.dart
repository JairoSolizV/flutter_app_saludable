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
        final List<dynamic> data = response.data is List ? response.data : response.data['content'] ?? []; 
        
        return data.map<Product>((json) {
           return Product(
             id: json['id'].toString(),
             name: json['nombre'] ?? 'Sin nombre',
             description: json['descripcion'] ?? '',
             price: 0.0, // Backend no envía precio aún
             category: 'General', 
             imageUrl: '', 
             hubId: json['hubId'],
             active: json['activo'] ?? true,
             available: json['disponible'] ?? false,
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
      // Endpoint: PATCH /api/clubes/{clubId}/productos/{productoId}/toggle
      await _client.patch('/clubes/$clubId/productos/$productId/toggle');
    } on DioException catch (e) {
      throw Exception('Error al cambiar disponibilidad: ${e.message}');
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
