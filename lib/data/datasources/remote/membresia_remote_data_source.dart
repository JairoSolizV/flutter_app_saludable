import 'package:dio/dio.dart';

abstract class MembresiaRemoteDataSource {
  Future<void> crearMembresia({required int usuarioId, required int clubId, int? nivelId, Map<String, dynamic>? extraData});
  Future<void> activarSocio({required int clubId, required String activationPayload, String? referidoPor, String? comoConocio});
}

class MembresiaRemoteDataSourceImpl implements MembresiaRemoteDataSource {
  final Dio _client;

  MembresiaRemoteDataSourceImpl(this._client);

  @override
  Future<void> activarSocio({
    required int clubId, 
    required String activationPayload, 
    String? referidoPor, 
    String? comoConocio
  }) async {
    try {
      final body = {
        'activationPayload': activationPayload.trim(),
        'referidoPor': referidoPor,
        'comoConocio': comoConocio,
      };

      final response = await _client.post(
        '/clubes/$clubId/socios/activar',
        data: body,
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Error al activar socio: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // LOG DEBUGER
      print('DIO ERROR: ${e.message}');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      
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
      throw Exception('Error ($statusCode): $msg');
    }
  }

  @override
  Future<void> crearMembresia({required int usuarioId, required int clubId, int? nivelId, Map<String, dynamic>? extraData}) async {
    try {
      final queryParams = {
        'usuarioId': usuarioId,
        'clubId': clubId,
      };
      if (nivelId != null && nivelId > 0) {
        queryParams['nivelId'] = nivelId;
      }

      final body = extraData ?? {};

      final response = await _client.post(
        '/membresias',
        queryParameters: queryParams,
        data: body, 
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
