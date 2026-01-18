import 'package:dio/dio.dart';
import '../../../domain/entities/product.dart';

abstract class ProductRemoteDataSource {
  Future<List<Product>> getProducts({int? clubId});
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final Dio _client;

  ProductRemoteDataSourceImpl(this._client);

  @override
  Future<List<Product>> getProducts({int? clubId}) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (clubId != null) {
        queryParameters['clubId'] = clubId;
      }

      final response = await _client.get('/productos', queryParameters: queryParameters);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : response.data['content'] ?? []; 
        
        return data.map<Product>((json) {
           return Product(
             id: json['id'].toString(),
             name: json['nombre'] ?? 'Sin nombre',
             description: json['descripcion'] ?? '',
             price: (json['precio'] as num).toDouble(),
             category: json['categoria'] ?? 'General',
             imageUrl: json['urlFoto'] ?? '',
           );
        }).toList();
      } else {
        throw Exception('Error al cargar productos: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de red al cargar productos: ${e.message}');
    }
  }

  Future<void> createProduct(Product product, int clubId) async {
    try {
      final data = {
        'nombre': product.name,
        'descripcion': product.description,
        'precio': product.price,
        'categoria': product.category,
        'urlFoto': product.imageUrl.isNotEmpty ? product.imageUrl : null,
      };

      await _client.post(
        '/productos',
        queryParameters: {'clubId': clubId}, // Backend requiere clubId como param
        data: data,
      );
    } on DioException catch (e) {
      throw Exception('Error al crear producto: ${e.response?.data['message'] ?? e.message}');
    }
  }
}
