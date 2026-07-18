import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/errors/throw_app_error.dart';
import '../../../domain/entities/pre_socio.dart';
import '../../../domain/entities/mision_pre_socio.dart';

abstract class PreSocioRemoteDataSource {
  Future<PreSocio> crearPreSocio({
    required int clubId,
    required String nombre,
    required String telefono,
    int? referidoPorMembresiaId,
  });
  Future<List<PreSocio>> getPreSocios(int clubId);
  Future<void> actualizarPreSocio(int preSocioId, String estado);
  Future<MisionPreSocio> crearMision({
    required int preSocioId,
    required String nombre,
    String? descripcion,
    required int metaCantidad,
    String? fechaLimite,
  });
  Future<MisionPreSocio> incrementarProgreso(int misionId);
  Future<void> eliminarMision(int misionId);
}

class PreSocioRemoteDataSourceImpl implements PreSocioRemoteDataSource {
  final Dio _client;

  PreSocioRemoteDataSourceImpl(this._client);

  @override
  Future<PreSocio> crearPreSocio({
    required int clubId,
    required String nombre,
    required String telefono,
    int? referidoPorMembresiaId,
  }) async {
    try {
      final response = await _client.post(
        '/clubes/$clubId/prospectos',
        data: {
          'nombre': nombre,
          'telefono': telefono,
          if (referidoPorMembresiaId != null)
            'referidoPorMembresiaId': referidoPorMembresiaId,
        },
      );
      return PreSocio.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error creando pre-socio', stackTrace: st);
    }
  }

  @override
  Future<List<PreSocio>> getPreSocios(int clubId) async {
    try {
      final response = await _client.get('/clubes/$clubId/prospectos');
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((e) => PreSocio.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404) return [];
      throwDioAsApp(e, fallback: 'Error obteniendo pre-socios', stackTrace: st);
    }
  }

  @override
  Future<void> actualizarPreSocio(int preSocioId, String estado) async {
    try {
      await _client.patch('/prospectos/$preSocioId', data: {'estado': estado});
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error actualizando pre-socio', stackTrace: st);
    }
  }

  @override
  Future<MisionPreSocio> crearMision({
    required int preSocioId,
    required String nombre,
    String? descripcion,
    required int metaCantidad,
    String? fechaLimite,
  }) async {
    try {
      final response = await _client.post(
        '/prospectos/$preSocioId/misiones',
        data: {
          'nombre': nombre,
          if (descripcion != null) 'descripcion': descripcion,
          'metaCantidad': metaCantidad,
          if (fechaLimite != null) 'fechaLimite': fechaLimite,
        },
      );
      return MisionPreSocio.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error creando misión', stackTrace: st);
    }
  }

  @override
  Future<MisionPreSocio> incrementarProgreso(int misionId) async {
    try {
      final response = await _client.patch('/misiones/$misionId/progreso');
      return MisionPreSocio.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error incrementando progreso', stackTrace: st);
    }
  }

  @override
  Future<void> eliminarMision(int misionId) async {
    try {
      await _client.delete('/misiones/$misionId');
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error eliminando misión', stackTrace: st);
    }
  }
}
