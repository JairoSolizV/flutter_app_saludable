import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/throw_app_error.dart';

/// Data source para operaciones relacionadas con QR
abstract class QRRemoteDataSource {
  /// Obtiene el QR del socio autenticado
  /// GET /api/socios/me/qr
  Future<QrResponse> getSocioQR();

  /// Valida el QR de un socio
  /// POST /api/qr/validar-socio
  /// Body: { "qr": "<string>", "clubId": <int> }
  Future<QRValidacionResponse> validarSocioQR(String qr, int clubId);
}

class QRRemoteDataSourceImpl implements QRRemoteDataSource {
  final Dio _client;

  QRRemoteDataSourceImpl(this._client);

  @override
  Future<QrResponse> getSocioQR() async {
    try {
      debugPrint('[DEBUG QR] Obteniendo QR del socio autenticado');
      debugPrint('[DEBUG QR] Endpoint: GET /api/socios/me/qr');

      final response = await _client.get('/socios/me/qr');

      debugPrint(
          '[DEBUG QR] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG QR] Response body: ${response.data}');

      if (response.statusCode == 200) {
        return QrResponse.fromJson(response.data);
      } else if (response.statusCode == 401) {
        throw UnauthorizedException(
            'No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        throw ForbiddenException(
            'No tienes permisos para obtener el QR. Debes ser socio.');
      } else {
        throw ServerException('Error al obtener QR',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      final statusCode = e.response?.statusCode;
      debugPrint('[DEBUG QR] DioException - Status: $statusCode');
      debugPrint('[DEBUG QR] Error: ${e.message}');
      throwDioAsApp(e, fallback: 'Error obteniendo QR', stackTrace: st);
    }
  }

  @override
  Future<QRValidacionResponse> validarSocioQR(String qr, int clubId) async {
    try {
      // Extraer el número de socio del formato "SOCIO:C2-000004" -> "C2-000004"
      String qrToSend = qr;
      if (qr.startsWith('SOCIO:')) {
        qrToSend = qr.substring(6); // Remover "SOCIO:" del inicio
      }

      debugPrint('[DEBUG QR] Validando QR del socio');
      debugPrint('[DEBUG QR] QR original: $qr');
      debugPrint('[DEBUG QR] QR a enviar: $qrToSend');
      debugPrint('[DEBUG QR] clubId: $clubId');
      debugPrint('[DEBUG QR] Endpoint: POST /api/qr/validar-socio');

      final response = await _client.post(
        '/qr/validar-socio',
        data: {
          'qr':
              qrToSend, // Enviar solo el número de socio sin el prefijo "SOCIO:"
          'clubId': clubId,
        },
      );

      debugPrint(
          '[DEBUG QR] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG QR] Response body: ${response.data}');

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map) {
          return QRValidacionResponse.fromJson(
              Map<String, dynamic>.from(responseData));
        }
        throw ServerException('Error al validar QR: respuesta inválida');
      } else {
        // El backend puede devolver 400 si el QR no es válido, pero con el response body
        final responseData = response.data;
        if (responseData is Map) {
          return QRValidacionResponse.fromJson(
              Map<String, dynamic>.from(responseData));
        }
        throw ServerException('Error al validar QR',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      final statusCode = e.response?.statusCode;
      debugPrint('[DEBUG QR] DioException - Status: $statusCode');
      debugPrint('[DEBUG QR] Error: ${e.message}');
      debugPrint('[DEBUG QR] Response data: ${e.response?.data}');

      // El backend puede devolver 400 con el response body válido
      if (statusCode == 400 || statusCode == 200) {
        final responseData = e.response?.data;
        if (responseData is Map) {
          return QRValidacionResponse.fromJson(
              Map<String, dynamic>.from(responseData));
        }
      }

      throwDioAsApp(e, fallback: 'Error validando QR', stackTrace: st);
    }
  }
}

/// Modelo para la respuesta del QR del socio
class QrResponse {
  final String tipo; // "ACTIVACION" o "SOCIO"
  final String qrPayload; // "ACTIVATE:{userId}" o "SOCIO:{numeroSocio}"
  final int? numeroSocio;
  final int? clubId;
  final String? clubNombre;
  final int? hubId;

  QrResponse({
    required this.tipo,
    required this.qrPayload,
    this.numeroSocio,
    this.clubId,
    this.clubNombre,
    this.hubId,
  });

  factory QrResponse.fromJson(Map<String, dynamic> json) {
    return QrResponse(
      tipo: json['tipo']?.toString() ?? '',
      qrPayload: json['qrPayload']?.toString() ?? '',
      numeroSocio: json['numeroSocio'] as int?,
      clubId: json['clubId'] as int?,
      clubNombre: json['clubNombre']?.toString(),
      hubId: json['hubId'] as int?,
    );
  }
}

/// Modelo para la respuesta de validación de QR del socio
class QRValidacionResponse {
  final int? membresiaId;
  final String? numeroSocio;
  final String? nombreCompleto;
  final String? estado;
  final String? nivelNombre;
  final int? rachaActual;
  final int? rachaMaxima;
  final String? mensaje;
  final bool valido;

  QRValidacionResponse({
    this.membresiaId,
    this.numeroSocio,
    this.nombreCompleto,
    this.estado,
    this.nivelNombre,
    this.rachaActual,
    this.rachaMaxima,
    this.mensaje,
    required this.valido,
  });

  factory QRValidacionResponse.fromJson(Map<String, dynamic> json) {
    return QRValidacionResponse(
      membresiaId: json['membresiaId'] as int?,
      numeroSocio: json['numeroSocio']?.toString(),
      nombreCompleto: json['nombreCompleto']?.toString(),
      estado: json['estado']?.toString(),
      nivelNombre: json['nivelNombre']?.toString(),
      rachaActual: json['rachaActual'] as int?,
      rachaMaxima: json['rachaMaxima'] as int?,
      mensaje: json['mensaje']?.toString(),
      valido: json['valido'] as bool? ?? false,
    );
  }
}
