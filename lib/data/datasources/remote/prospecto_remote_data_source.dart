import 'package:dio/dio.dart';
import '../../../domain/entities/prospecto.dart';
import '../../../domain/entities/mision_prospecto.dart';

abstract class ProspectoRemoteDataSource {
  Future<Prospecto> crearProspecto({
    required int clubId,
    required String nombre,
    required String telefono,
    int? referidoPorMembresiaId,
  });
  Future<List<Prospecto>> getProspectos(int clubId);
  Future<void> actualizarProspecto(int prospectoId, String estado);
  Future<MisionProspecto> crearMision({
    required int prospectoId,
    required String nombre,
    String? descripcion,
    required int metaCantidad,
    String? fechaLimite,
  });
  Future<MisionProspecto> incrementarProgreso(int misionId);
  Future<void> eliminarMision(int misionId);
}

class ProspectoRemoteDataSourceImpl implements ProspectoRemoteDataSource {
  final Dio _client;

  ProspectoRemoteDataSourceImpl(this._client);

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is String) return data;
    return e.message ?? 'Error desconocido';
  }

  @override
  Future<Prospecto> crearProspecto({
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
      return Prospecto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          'Error creando prospecto (${e.response?.statusCode}): ${_extractMessage(e)}');
    }
  }

  @override
  Future<List<Prospecto>> getProspectos(int clubId) async {
    try {
      final response = await _client.get('/clubes/$clubId/prospectos');
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((e) => Prospecto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw Exception('Error obteniendo prospectos: ${_extractMessage(e)}');
    }
  }

  @override
  Future<void> actualizarProspecto(int prospectoId, String estado) async {
    try {
      await _client.patch('/prospectos/$prospectoId', data: {'estado': estado});
    } on DioException catch (e) {
      throw Exception('Error actualizando prospecto: ${_extractMessage(e)}');
    }
  }

  @override
  Future<MisionProspecto> crearMision({
    required int prospectoId,
    required String nombre,
    String? descripcion,
    required int metaCantidad,
    String? fechaLimite,
  }) async {
    try {
      final response = await _client.post(
        '/prospectos/$prospectoId/misiones',
        data: {
          'nombre': nombre,
          if (descripcion != null) 'descripcion': descripcion,
          'metaCantidad': metaCantidad,
          if (fechaLimite != null) 'fechaLimite': fechaLimite,
        },
      );
      return MisionProspecto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error creando misión: ${_extractMessage(e)}');
    }
  }

  @override
  Future<MisionProspecto> incrementarProgreso(int misionId) async {
    try {
      final response = await _client.patch('/misiones/$misionId/progreso');
      return MisionProspecto.fromJson(response.data as Map<String, dynamic>);
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
