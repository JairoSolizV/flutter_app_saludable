import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/throw_app_error.dart';
import 'package:flutter/foundation.dart';
import '../../../core/pagination/paged_result.dart';
import '../../../domain/entities/club_membership.dart';
import '../../../domain/entities/attendance.dart';
import '../../../domain/entities/arbol_referidos.dart';

abstract class MembresiaRemoteDataSource {
  Future<void> crearMembresia(
      {required int usuarioId,
      required int clubId,
      int? nivelId,
      Map<String, dynamic>? extraData});
  Future<void> activarSocio(
      {required int clubId,
      required String activationPayload,
      int? referidoPorMembresiaId,
      String? comoConocio,
      required bool esClientePreferenteODistribuidor});
  Future<List<ClubMembership>> getMembresiasPorUsuario(int usuarioId);
  Future<List<Attendance>> getAsistencias(int membresiaId);
  Future<AsistenciaResponse> registrarAsistencia({
    required int membresiaId,
    required int clubId,
    required double latitud,
    required double longitud,
    double? precisionMetros,
  });
  Future<Attendance> registrarAsistenciaManual(
      {required int membresiaId, String? fecha, String? nota});
  Future<Map<String, dynamic>> getEstadoCombo(int membresiaId);
  Future<List<ClubMembership>> buscarMiembrosGlobal({String? query});

  /// Versión paginada de [buscarMiembrosGlobal].
  /// Endpoint: GET /membresias/buscar/paginado?q&page&size
  Future<PagedResult<ClubMembership>> buscarMiembrosGlobalPage({
    String? query,
    int page = 0,
    int size = 20,
  });

  Future<ArbolReferidos> getArbolReferidos(int membresiaId);
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
  Future<void> activarSocio(
      {required int clubId,
      required String activationPayload,
      int? referidoPorMembresiaId,
      String? comoConocio,
      required bool esClientePreferenteODistribuidor}) async {
    try {
      final body = {
        'activationPayload': activationPayload.trim(),
        'referidoPor': referidoPorMembresiaId?.toString(),
        'comoConocio': comoConocio,
        'esClientePreferenteODistribuidor': esClientePreferenteODistribuidor,
      };

      final response = await _client.post(
        '/clubes/$clubId/socios/activar',
        data: body,
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw ServerException('Error al activar socio',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error en membresías', stackTrace: st);
    }
  }

  @override
  Future<void> crearMembresia(
      {required int usuarioId,
      required int clubId,
      int? nivelId,
      Map<String, dynamic>? extraData}) async {
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
        throw ServerException('Error al crear membresía',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error en membresías', stackTrace: st);
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
        throw ServerException('Error cargando membresías',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      throwDioAsApp(e, fallback: 'Error al obtener membresías', stackTrace: st);
    } catch (e, st) {
      rethrowApp(e, fallback: 'Error al obtener membresías', stackTrace: st);
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
        throw ServerException('Error cargando asistencias',
            statusCode: response.statusCode);
      }
    } catch (e, st) {
      rethrowApp(e, fallback: 'Error al obtener asistencias', stackTrace: st);
    }
  }

  @override
  Future<AsistenciaResponse> registrarAsistencia({
    required int membresiaId,
    required int clubId,
    required double latitud,
    required double longitud,
    double? precisionMetros,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'membresiaId': membresiaId,
        'clubId': clubId,
        'latitud': latitud,
        'longitud': longitud,
      };
      if (precisionMetros != null &&
          precisionMetros.isFinite &&
          !precisionMetros.isNaN) {
        queryParameters['precisionMetros'] = precisionMetros;
      }

      debugPrint(
        '[DEBUG MEMBRESIA] Registrando asistencia - membresiaId: $membresiaId, '
        'clubId: $clubId, lat: $latitud, lng: $longitud, '
        'precision: ${queryParameters['precisionMetros']}',
      );

      final response = await _client.post(
        '/asistencias/registrar',
        queryParameters: queryParameters,
      );

      debugPrint(
          '[DEBUG MEMBRESIA] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG MEMBRESIA] Response body: ${response.data}');

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw ServerException('Error al registrar asistencia',
            statusCode: response.statusCode);
      }

      // Parsear respuesta para obtener racha actual y máxima
      final responseData = response.data;
      if (responseData is Map) {
        return AsistenciaResponse.fromJson(
            Map<String, dynamic>.from(responseData));
      }

      // Si no hay datos, retornar respuesta vacía
      return AsistenciaResponse(
        rachaActual: null,
        rachaMaxima: null,
        mensaje: 'Asistencia registrada correctamente',
      );
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error registro asistencia', stackTrace: st);
    } catch (e, st) {
      rethrowApp(e, fallback: 'Error al registrar asistencia', stackTrace: st);
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
        throw ServerException('Error al registrar asistencia',
            statusCode: response.statusCode);
      }
      return Attendance.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error registrando asistencia manual', stackTrace: st);
    }
  }

  @override
  Future<Map<String, dynamic>> getEstadoCombo(int membresiaId) async {
    try {
      final response =
          await _client.get('/membresias/$membresiaId/estado-combo');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404)
        return {'haConsumidoCombo': false, 'totalCombosConsumidos': 0};
      throwDioAsApp(e,
          fallback: 'Error obteniendo estado de combo', stackTrace: st);
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
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error en membresías', stackTrace: st);
    } catch (e, st) {
      rethrowApp(e, fallback: 'Error al buscar miembros', stackTrace: st);
    }
  }

  @override
  Future<PagedResult<ClubMembership>> buscarMiembrosGlobalPage({
    String? query,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _client.get(
        '/membresias/buscar/paginado',
        queryParameters: {
          'page': page,
          'size': size,
          if (query != null && query.isNotEmpty) 'q': query,
        },
      );

      final dynamic data = response.data;
      if (data is! Map) {
        throw ServerException('Respuesta inesperada al buscar socios');
      }
      return PagedResult<ClubMembership>.fromJson(
        Map<String, dynamic>.from(data),
        (json) => ClubMembership.fromJson(json),
      );
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error en membresías', stackTrace: st);
    } catch (e, st) {
      rethrowApp(e, fallback: 'Error al buscar miembros', stackTrace: st);
    }
  }

  @override
  Future<ArbolReferidos> getArbolReferidos(int membresiaId) async {
    try {
      final response =
          await _client.get('/membresias/$membresiaId/arbol-referidos');
      if (response.statusCode == 200) {
        return ArbolReferidos.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ServerException('Error al obtener el árbol de referidos',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error en membresías', stackTrace: st);
    } catch (e, st) {
      rethrowApp(e,
          fallback: 'Error al obtener el árbol de referidos', stackTrace: st);
    }
  }
}
