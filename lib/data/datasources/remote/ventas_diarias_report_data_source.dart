import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../domain/entities/ventas_diarias_reporte.dart';

/// Consulta y descarga del reporte diario detallado de ventas.
class VentasDiariasReportDataSource {
  final Dio _client;

  VentasDiariasReportDataSource(this._client);

  /// GET /api/reportes/anfitrion/{clubId}/ventas-diarias?fecha=...
  Future<VentasDiariasReporte> obtenerReporte({
    required int clubId,
    required DateTime fecha,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/reportes/anfitrion/$clubId/ventas-diarias',
      queryParameters: {'fecha': _soloFecha(fecha)},
      options: Options(
        validateStatus: (status) => status != null && status < 600,
      ),
    );

    final code = response.statusCode ?? 0;
    if (code == 200 && response.data != null) {
      return VentasDiariasReporte.fromJson(response.data!);
    }

    if (kDebugMode) {
      debugPrint('[VENTAS-DIARIAS] Error HTTP $code clubId=$clubId');
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: _mensajeError(code, response),
    );
  }

  /// GET /api/reportes/anfitrion/{clubId}/ventas-diarias/descargar
  Future<List<int>> descargarReporte({
    required int clubId,
    required DateTime fecha,
    required String formato,
  }) async {
    final response = await _client.get<List<int>>(
      '/reportes/anfitrion/$clubId/ventas-diarias/descargar',
      queryParameters: {
        'fecha': _soloFecha(fecha),
        'formato': formato,
      },
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
        validateStatus: (status) => status != null && status < 600,
        headers: {'Accept': '*/*'},
      ),
    );

    final code = response.statusCode ?? 0;
    if (code == 200 && response.data != null) {
      return response.data!;
    }

    if (kDebugMode) {
      debugPrint('[VENTAS-DIARIAS-DL] Error HTTP $code clubId=$clubId');
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: _mensajeError(code, response),
    );
  }

  String _soloFecha(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _mensajeError(int code, Response<dynamic>? response) {
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      final serverMsg = data['data'] as String? ?? data['message'] as String?;
      if (serverMsg != null && serverMsg.isNotEmpty) {
        return serverMsg;
      }
    }
    switch (code) {
      case 401:
        return 'Sesión expirada. Inicia sesión de nuevo.';
      case 403:
        return 'No tienes permiso para ver este reporte.';
      case 404:
        return 'Club no encontrado.';
      case 500:
        return 'Error en el servidor al generar el reporte. Reinicia el backend con los últimos cambios.';
      default:
        return 'No se pudo obtener el reporte (código $code).';
    }
  }
}
