import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Descarga de reportes de gestión para anfitriones (binario PDF / Excel).
class ReportRemoteDataSource {
  final Dio _client;

  ReportRemoteDataSource(this._client);

  /// GET /api/reportes/anfitrion/{clubId}/descargar
  Future<List<int>> descargarReporte({
    required int clubId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required String formato,
  }) async {
    final inicio = _soloFecha(fechaInicio);
    final fin = _soloFecha(fechaFin);

    final response = await _client.get<List<int>>(
      '/reportes/anfitrion/$clubId/descargar',
      queryParameters: {
        'fechaInicio': inicio,
        'fechaFin': fin,
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
      debugPrint('[REPORTE] Error HTTP $code clubId=$clubId');
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: _mensajeError(code),
    );
  }

  String _soloFecha(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _mensajeError(int code) {
    switch (code) {
      case 400:
        return 'Rango de fechas inválido o formato no permitido.';
      case 401:
        return 'Sesión expirada. Inicia sesión de nuevo.';
      case 403:
        return 'No tienes permiso para descargar este reporte.';
      case 404:
        return 'No se encontró el recurso solicitado.';
      default:
        return 'No se pudo generar el reporte (código $code).';
    }
  }
}
