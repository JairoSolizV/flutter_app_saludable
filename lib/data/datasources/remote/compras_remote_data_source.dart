import 'package:dio/dio.dart';
import '../../../domain/entities/compra_manual.dart';

abstract class ComprasRemoteDataSource {
  Future<List<CompraManual>> getComprasPorMembresia(int membresiaId);
  Future<CompraManual> registrarCompra({
    required int membresiaId,
    required int clubId,
    required String descripcion,
    required double monto,
    required String fecha,
  });
}

class ComprasRemoteDataSourceImpl implements ComprasRemoteDataSource {
  final Dio _client;

  ComprasRemoteDataSourceImpl(this._client);

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is String) return data;
    return e.message ?? 'Error desconocido';
  }

  @override
  Future<List<CompraManual>> getComprasPorMembresia(int membresiaId) async {
    try {
      final response = await _client.get('/membresias/$membresiaId/compras');
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((e) => CompraManual.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw Exception('Error obteniendo compras: ${_extractMessage(e)}');
    }
  }

  @override
  Future<CompraManual> registrarCompra({
    required int membresiaId,
    required int clubId,
    required String descripcion,
    required double monto,
    required String fecha,
  }) async {
    try {
      final response = await _client.post(
        '/membresias/$membresiaId/compras',
        data: {
          'descripcion': descripcion,
          'monto': monto,
          'fecha': fecha,
        },
      );
      return CompraManual.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          'Error registrando compra (${e.response?.statusCode}): ${_extractMessage(e)}');
    }
  }
}
