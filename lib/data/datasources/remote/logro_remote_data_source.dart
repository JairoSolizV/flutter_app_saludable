import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/logro.dart';

abstract class LogroRemoteDataSource {
  Future<Logro> createLogro(Logro logro);
  Future<List<Logro>> getLogros();
  Future<List<LogroProgreso>> getProgresoSocio(int membresiaId);
}

class LogroRemoteDataSourceImpl implements LogroRemoteDataSource {
  final Dio _client;

  LogroRemoteDataSourceImpl(this._client);

  @override
  Future<Logro> createLogro(Logro logro) async {
    try {
      debugPrint('[DEBUG LOGROS] Creando logro en el host...');
      
      String _formatDate(DateTime? d) {
        if (d == null) return '';
        return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }

      final data = {
        'nombre': logro.nombre,
        'descripcion': logro.descripcion,
        'iconoUrl': logro.iconoUrl,
        'puntosRecompensa': logro.puntosRecompensa,
        'fechaInicio': _formatDate(logro.fechaInicio),
        'fechaFin': _formatDate(logro.fechaFin),
        'requisitos': logro.requisitos.map((r) => r.toJson()).toList(),
      };

      final response = await _client.post(
        '/logros',
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Logro.fromJson(response.data);
      } else {
        throw Exception('Error al crear logro: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('[DEBUG LOGROS] DioException al crear logro: ${e.response?.data}');
      throw Exception('Error de red al crear logro: ${e.message}');
    }
  }

  @override
  Future<List<Logro>> getLogros() async {
    try {
      debugPrint('[DEBUG LOGROS] Obteniendo logros...');
      final response = await _client.get('/logros');
      
      if (response.statusCode == 200) {
        List<dynamic> data = [];
        if (response.data is List) {
          data = response.data;
        } else if (response.data is Map && response.data['data'] is List) {
          data = response.data['data'];
        }

        return data.map((json) => Logro.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar logros: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('[DEBUG LOGROS] DioException al obtener logros: ${e.response?.data}');
      throw Exception('Error de red al cargar logros: ${e.message}');
    }
  }

  @override
  Future<List<LogroProgreso>> getProgresoSocio(int membresiaId) async {
    try {
      debugPrint('[DEBUG LOGROS] Obteniendo progreso del socio con membresia $membresiaId');
      final response = await _client.get('/logros/socio/$membresiaId/progreso');
      
      if (response.statusCode == 200) {
        List<dynamic> data = [];
        if (response.data is List) {
          data = response.data;
        } else if (response.data is Map && response.data['data'] is List) {
          data = response.data['data'];
        }

        return data.map((json) => LogroProgreso.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar progreso: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('[DEBUG LOGROS] DioException al obtener progreso: ${e.response?.data}');
      throw Exception('Error de red al cargar progreso: ${e.message}');
    }
  }
}
