import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/club_membership.dart';
import '../../../domain/entities/attendance.dart';

abstract class MembresiaRemoteDataSource {
  Future<void> crearMembresia({required int usuarioId, required int clubId, int? nivelId, Map<String, dynamic>? extraData});
  Future<void> activarSocio({required int clubId, required String activationPayload, int? referidoPorMembresiaId, String? comoConocio});
  Future<List<ClubMembership>> getMembresiasPorUsuario(int usuarioId);
  Future<List<Attendance>> getAsistencias(int membresiaId);
  Future<AsistenciaResponse> registrarAsistencia({
    required int membresiaId,
    required int clubId,
    required double latitud,
    required double longitud,
  });
  Future<Attendance> registrarAsistenciaManual({required int membresiaId, String? fecha, String? nota});
  Future<Map<String, dynamic>> getEstadoCombo(int membresiaId);
  Future<List<ClubMembership>> buscarMiembrosGlobal({String? query});
}

/// Modelo para la respuesta de registro de asistencia
class AsistenciaResponse {
  final int? rachaActual;
  final int? rachaMaxima;
  final String? mensaje;
  final String? clubNombre;
  final String? fechaHora;

  AsistenciaResponse({
    this.rachaActual,
    this.rachaMaxima,
    this.mensaje,
    this.clubNombre,
    this.fechaHora,
  });

  factory AsistenciaResponse.fromJson(Map<String, dynamic> json) {
    return AsistenciaResponse(
      rachaActual: json['rachaActual'] as int?,
      rachaMaxima: json['rachaMaxima'] as int?,
      mensaje: json['mensaje']?.toString(),
      clubNombre: json['clubNombre']?.toString(),
      fechaHora: json['fechaHora']?.toString(),
    );
  }
}

class MembresiaRemoteDataSourceImpl implements MembresiaRemoteDataSource {
  final Dio _client;

  MembresiaRemoteDataSourceImpl(this._client);

  @override
  Future<void> activarSocio({
    required int clubId, 
    required String activationPayload, 
    int? referidoPorMembresiaId, 
    String? comoConocio
  }) async {
    try {
      final body = {
        'activationPayload': activationPayload.trim(),
        'referidoPor': referidoPorMembresiaId?.toString(),
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

      if (e.response?.data != null) {
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
  Future<AsistenciaResponse> registrarAsistencia({
    required int membresiaId, 
    required int clubId,
    required double latitud,
    required double longitud,
  }) async {
    try {
      // Endpoint correcto según el backend: POST /api/asistencias/registrar
      // Con query params: membresiaId, clubId, qrClub (opcional)
      debugPrint('[DEBUG MEMBRESIA] Registrando asistencia - membresiaId: $membresiaId, clubId: $clubId');
      debugPrint('[DEBUG MEMBRESIA] Endpoint: POST /api/asistencias/registrar?membresiaId=$membresiaId&clubId=$clubId');
      
      final response = await _client.post(
        '/asistencias/registrar',
        queryParameters: {
          'membresiaId': membresiaId,
          'clubId': clubId,
          // qrClub es opcional, no lo enviamos si no es necesario
        },
      );

      debugPrint('[DEBUG MEMBRESIA] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG MEMBRESIA] Response body: ${response.data}');

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Error al registrar asistencia: ${response.statusCode}');
      }

      // Parsear respuesta para obtener racha actual y máxima
      final responseData = response.data;
      if (responseData is Map) {
        return AsistenciaResponse.fromJson(Map<String, dynamic>.from(responseData));
      }
      
      // Si no hay datos, retornar respuesta vacía
      return AsistenciaResponse(
        rachaActual: null,
        rachaMaxima: null,
        mensaje: 'Asistencia registrada correctamente',
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      debugPrint('[DEBUG MEMBRESIA] DioException - Status: $statusCode');
      debugPrint('[DEBUG MEMBRESIA] Error: ${e.message}');
      debugPrint('[DEBUG MEMBRESIA] Response data: ${e.response?.data}');
      
      if (statusCode == 401) {
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (statusCode == 403) {
        throw Exception('No tienes permisos para registrar asistencia.');
      } else if (statusCode == 500) {
        throw Exception('Error del servidor. Por favor intenta más tarde.');
      }
      
      final responseData = e.response?.data;
      String msg = 'Error desconocido';
      
      if (responseData is Map) {
        msg = responseData['message']?.toString() ?? 
              responseData['error']?.toString() ?? 
              e.message ?? 'Error desconocido';
        
        // Si el backend responde que ya se registró hoy, devolver respuesta con mensaje
        if (msg.toLowerCase().contains('ya registraste') || 
            msg.toLowerCase().contains('ya existe') ||
            msg.toLowerCase().contains('duplicado')) {
          return AsistenciaResponse.fromJson(Map<String, dynamic>.from(responseData));
        }
      } else if (responseData is String) {
        msg = responseData;
      } else {
        msg = e.message ?? 'Error desconocido';
      }
      
      throw Exception('Error registro asistencia: $msg');
    } catch (e) {
      debugPrint('[DEBUG MEMBRESIA] Error general registrando asistencia: $e');
      throw Exception('Error al registrar asistencia: $e');
    }
  }

  @override
  Future<Attendance> registrarAsistenciaManual({
    required int membresiaId,
    String? fecha,
    String? nota,
  }) async {
    try {
      final response = await _client.post(
        '/membresias/$membresiaId/asistencias',
        data: {
          if (fecha != null) 'fecha': fecha,
          if (nota != null) 'nota': nota,
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error al registrar asistencia: ${response.statusCode}');
      }
      return Attendance.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg = e.message ?? 'Error desconocido';
      if (data is Map && data['message'] != null) msg = data['message'].toString();
      if (e.response?.statusCode == 409) {
        throw Exception('Ya existe una asistencia registrada para hoy.');
      }
      throw Exception('Error registrando asistencia manual: $msg');
    }
  }

  @override
  Future<Map<String, dynamic>> getEstadoCombo(int membresiaId) async {
    try {
      final response = await _client.get('/membresias/$membresiaId/estado-combo');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return {'haConsumidoCombo': false, 'totalCombosConsumidos': 0};
      throw Exception('Error obteniendo estado de combo: ${e.message}');
    }
  }

  @override
  Future<List<ClubMembership>> buscarMiembrosGlobal({String? query}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (query != null && query.isNotEmpty) {
        queryParams['q'] = query;
      }

      final response = await _client.get(
        '/membresias/buscar',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ClubMembership.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Error al buscar miembros');
    } catch (e) {
      throw Exception('Error al buscar miembros: $e');
    }
  }
}

