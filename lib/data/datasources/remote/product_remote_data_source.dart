import 'package:dio/dio.dart';
import '../../../domain/entities/product.dart';

abstract class ProductRemoteDataSource {
  Future<List<Product>> getProducts();
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final Dio _client;

  ProductRemoteDataSourceImpl(this._client);

  @override
  Future<List<Product>> getProducts() async {
    try {
      // Endpoint /api/productos (asumiendo que devuelve lista directa o paginada)
      // Ajuste según doc: GET /api/productos
      final response = await _client.get('/productos');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : response.data['content'] ?? []; // Handling posible paginación Spring Boot
        
        return data.map<Product>((json) {
           // Mapeo defensivo
           return Product(
             id: json['id'].toString(),
             name: json['nombre'] ?? 'Sin nombre',
             description: json['descripcion'] ?? '',
             price: (json['precio'] as num).toDouble(),
             category: json['categoria'] ?? 'General',
             imageUrl: json['urlFoto'] ?? '', // Ajustar según DTO real
           );
        }).toList();
      } else {
        throw Exception('Error al cargar productos: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de red al cargar productos: ${e.message}');
    }
  }
}
