import 'package:dio/dio.dart';
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

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is String) return data;
    return e.message ?? 'Error desconocido';
  }

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
    } on DioException catch (e) {
      throw Exception(
          'Error creando pre-socio (${e.response?.statusCode}): ${_extractMessage(e)}');
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw Exception('Error obteniendo pre-socios: ${_extractMessage(e)}');
    }
  }

  @override
  Future<void> actualizarPreSocio(int preSocioId, String estado) async {
    try {
      await _client.patch('/prospectos/$preSocioId', data: {'estado': estado});
    } on DioException catch (e) {
      throw Exception('Error actualizando pre-socio: ${_extractMessage(e)}');
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
    } on DioException catch (e) {
      throw Exception('Error creando misión: ${_extractMessage(e)}');
    }
  }

  @override
  Future<MisionPreSocio> incrementarProgreso(int misionId) async {
    try {
      final response = await _client.patch('/misiones/$misionId/progreso');
      return MisionPreSocio.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error incrementando progreso: ${_extractMessage(e)}');
    }
  }

  @override
  Future<void> eliminarMision(int misionId) async {
    try {
      await _client.delete('/misiones/$misionId');
    } on DioException catch (e) {
      throw Exception('Error eliminando misión: ${_extractMessage(e)}');
    }
  }
}
