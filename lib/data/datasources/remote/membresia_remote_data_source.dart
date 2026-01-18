import 'package:dio/dio.dart';

abstract class MembresiaRemoteDataSource {
  Future<void> crearMembresia({required int usuarioId, required int clubId, int? nivelId});
}

class MembresiaRemoteDataSourceImpl implements MembresiaRemoteDataSource {
  final Dio _client;

  MembresiaRemoteDataSourceImpl(this._client);

  @override
  Future<void> crearMembresia({required int usuarioId, required int clubId, int? nivelId}) async {
    try {
      final data = {
        'usuarioId': usuarioId,
        'clubId': clubId,
      };
      if (nivelId != null) {
        data['nivelId'] = nivelId;
      }

      final response = await _client.post(
        '/membresias',
        data: data, 
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Error al crear membresía: ${response.statusCode}');
      }
    } on DioException catch (e) {
      String msg = e.message ?? 'Error desconocido';
      final statusCode = e.response?.statusCode ?? 'N/A';
      String rawData = '';

      if (e.response?.data != null) {
        rawData = e.response!.data.toString();
        if (e.response!.data is Map && e.response!.data['message'] != null) {
          msg = e.response!.data['message'];
        } else if (e.response!.data is String) {
          msg = e.response!.data; 
        } else {
             msg = e.response!.data.toString();
        }
      }
      throw Exception('Error ($statusCode): $msg | RAW: $rawData');
    }
  }
}
