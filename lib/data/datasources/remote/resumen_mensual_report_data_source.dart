import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../domain/entities/resumen_mensual_ventas.dart';

/// Consulta y descarga del resumen mensual de ventas (mes calendario).
class ResumenMensualReportDataSource {
  final Dio _client;

  ResumenMensualReportDataSource(this._client);

  /// GET /api/reportes/anfitrion/{clubId}/resumen-mensual?anio=&mes=
  Future<ResumenMensualVentas> obtenerReporte({
    required int clubId,
    required int anio,
    required int mes,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/reportes/anfitrion/$clubId/resumen-mensual',
      queryParameters: {'anio': anio, 'mes': mes},
      options: Options(
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final code = response.statusCode ?? 0;
    if (code == 200 && response.data != null) {
      return ResumenMensualVentas.fromJson(response.data!);
    }

    if (kDebugMode) {
      debugPrint('[RESUMEN-MENSUAL] Error HTTP $code clubId=$clubId');
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: _mensajeError(code),
    );
  }

  /// GET /api/reportes/anfitrion/{clubId}/resumen-mensual/descargar
  Future<List<int>> descargarReporte({
    required int clubId,
    required int anio,
    required int mes,
    required String formato,
  }) async {
    final response = await _client.get<List<int>>(
      '/reportes/anfitrion/$clubId/resumen-mensual/descargar',
      queryParameters: {
        'anio': anio,
        'mes': mes,
        'formato': formato,
      },
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
        headers: {'Accept': '*/*'},
      ),
    );

    final code = response.statusCode ?? 0;
    if (code == 200 && response.data != null) {
      return response.data!;
    }

    if (kDebugMode) {
      debugPrint('[RESUMEN-MENSUAL-DL] Error HTTP $code clubId=$clubId');
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: _mensajeError(code),
    );
  }

  String _mensajeError(int code) {
    switch (code) {
      case 401:
        return 'Sesión expirada. Inicia sesión de nuevo.';
      case 403:
        return 'No tienes permiso para ver este reporte.';
      case 404:
        return 'Club no encontrado.';
      default:
        return 'No se pudo obtener el reporte (código $code).';
    }
  }
}
