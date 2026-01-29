import 'package:dio/dio.dart';
import '../../../domain/entities/club_membership.dart';
import '../../../domain/entities/attendance.dart';

abstract class MembresiaRemoteDataSource {
  Future<void> crearMembresia({required int usuarioId, required int clubId, int? nivelId, Map<String, dynamic>? extraData});
  Future<void> activarSocio({required int clubId, required String activationPayload, String? referidoPor, String? comoConocio});
  Future<List<ClubMembership>> getMembresiasPorUsuario(int usuarioId);
  Future<List<Attendance>> getAsistencias(int membresiaId);
  Future<void> registrarAsistencia({required int membresiaId, required int clubId});
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
  @override
  Future<List<ClubMembership>> getMembresiasPorUsuario(int usuarioId) async {
    try {
      final response = await _client.get('/membresias/usuario/$usuarioId');
      
      if (response.statusCode == 200) {
        final dynamic data = response.data;
        
        if (data is List) {
          return data.map((json) => ClubMembership.fromJson(json)).toList();
        } else if (data is Map<String, dynamic>) {
          // Si devuelve un solo objeto, lo envolvemos en una lista
          return [ClubMembership.fromJson(data)];
        } else {
           return [];
        }
      } else {
         if (response.statusCode == 404) return [];
         throw Exception('Error cargando membresías: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        return [];
      }
      throw Exception('Error al obtener membresías: $e');
    }
  }

  @override
  Future<List<Attendance>> getAsistencias(int membresiaId) async {
    try {
      final response = await _client.get('/asistencias/socio/$membresiaId');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Attendance.fromJson(json)).toList();
      } else {
        throw Exception('Error cargando asistencias: ${response.statusCode}');
      }
    } catch (e) {
       throw Exception('Error al obtener asistencias: $e');
    }
  }
  @override
  Future<void> registrarAsistencia({required int membresiaId, required int clubId}) async {
    try {
      // Endpoint tentativo basado en convención. Ajustar si el backend es diferente.
      // Payload típicamente es { "membresiaId": x, "clubId": y }
      final body = {
        'membresiaId': membresiaId,
        'clubId': clubId,
        'fechaHora': DateTime.now().toIso8601String(), // Opcional, el backend suele poner el timestamp
      };

      final response = await _client.post(
        '/asistencias', // Asumiendo POST /api/asistencias base
        data: body,
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Error al registrar asistencia: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException) {
         final msg = e.response?.data?.toString() ?? e.message;
         throw Exception('Error registro asistencia: $msg');
      }
      throw Exception('Error al registrar asistencia: $e');
    }
  }
}
