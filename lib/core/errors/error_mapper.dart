import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/api/public_api_paths.dart';
import 'package:flutter_app_saludable/core/attendance/attendance_error_messages.dart';
import 'package:flutter_app_saludable/core/clubs/club_location.dart';
import 'package:flutter_app_saludable/core/clubs/club_prefix.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';

/// Mapea [DioException] y respuestas del backend a [AppException] seguras.
class ErrorMapper {
  ErrorMapper._();

  static const _generic = 'Ocurrió un error. Intenta nuevamente.';
  static const _server = 'Error del servidor. Por favor intenta más tarde.';
  static const _network = 'Error de conexión. Verifica tu internet.';
  static const _timeout = 'Tiempo de espera agotado. Verifica tu conexión.';
  static const _forbidden = 'No tienes permisos para realizar esta acción.';
  static const _notFound = 'Recurso no encontrado.';
  static const _conflict = 'Conflicto con el estado actual del recurso.';
  static const _rateLimit =
      'Demasiadas solicitudes. Espera un momento e intenta de nuevo.';
  static const _unauthorized = 'No autenticado. Inicia sesión nuevamente.';
  static const _validation = 'Datos inválidos. Verifica la información.';

  /// Longitud máxima de mensajes públicos.
  static const int maxPublicMessageLength = 280;

  /// Convierte un [DioException] en [AppException] tipada.
  static AppException fromDio(
    DioException e, {
    String? fallback,
  }) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(_timeout, cause: e.type);
      case DioExceptionType.connectionError:
        return NetworkException(_network, cause: e.type);
      case DioExceptionType.cancel:
        return NetworkException('Solicitud cancelada.', cause: e.type);
      case DioExceptionType.badCertificate:
        return NetworkException(
          'No se pudo establecer una conexión segura.',
          cause: e.type,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final status = e.response?.statusCode;
    final parsed = _parseBody(e.response?.data);
    final message = sanitizePublicMessage(parsed.message, fallback: fallback);
    final handled =
        e.requestOptions.extra[kRequestSessionExpiredHandled] == true;

    switch (status) {
      case 400:
      case 422:
        if (parsed.code == ResetCodeInvalidException.errorCode) {
          return ResetCodeInvalidException(
            message ?? ResetCodeInvalidException.defaultMessage,
          );
        }
        if (parsed.code == ResetTokenInvalidException.errorCode) {
          return ResetTokenInvalidException(
            message ?? ResetTokenInvalidException.defaultMessage,
          );
        }
        if (parsed.code == ComboRequiredException.errorCode) {
          return ComboRequiredException(
            message ?? ComboRequiredException.defaultMessage,
          );
        }
        if (AttendanceErrorCodes.isAttendanceCode(parsed.code)) {
          return ValidationException(
            AttendanceErrorMessages.forCode(parsed.code!),
            statusCode: status,
            code: parsed.code,
            cause: e.type,
          );
        }
        if (ClubLocationErrorCodes.isClubLocationCode(parsed.code)) {
          return ValidationException(
            ClubLocationErrorMessages.forCode(parsed.code!),
            statusCode: status,
            code: parsed.code,
            cause: e.type,
          );
        }
        if (ClubPrefixErrorCodes.isClubPrefixCode(parsed.code)) {
          return ValidationException(
            ClubPrefixErrorMessages.forCode(parsed.code!),
            statusCode: status,
            code: parsed.code,
            cause: e.type,
          );
        }
        return ValidationException(
          message ?? _validation,
          statusCode: status,
          code: parsed.code,
          fieldErrors: parsed.fieldErrors,
          cause: e.type,
        );
      case 401:
        if (handled) {
          return SessionExpiredException(
            message ?? 'Tu sesión expiró. Inicia sesión nuevamente.',
          );
        }
        return UnauthorizedException(
          message ?? _unauthorized,
          code: parsed.code,
          cause: e.type,
        );
      case 403:
        if (parsed.code == EmailNotVerifiedException.errorCode) {
          return EmailNotVerifiedException(
            message ?? 'Debes verificar tu correo para continuar.',
          );
        }
        return ForbiddenException(
          message ?? _forbidden,
          code: parsed.code,
          cause: e.type,
        );
      case 404:
        return NotFoundException(
          message ?? _notFound,
          code: parsed.code,
          cause: e.type,
        );
      case 409:
        if (ClubLocationErrorCodes.isClubLocationCode(parsed.code)) {
          return ValidationException(
            ClubLocationErrorMessages.forCode(parsed.code!),
            statusCode: status,
            code: parsed.code,
            cause: e.type,
          );
        }
        if (ClubPrefixErrorCodes.isClubPrefixCode(parsed.code)) {
          return ValidationException(
            ClubPrefixErrorMessages.forCode(parsed.code!),
            statusCode: status,
            code: parsed.code,
            cause: e.type,
          );
        }
        return ConflictException(
          message ?? _conflict,
          code: parsed.code,
          cause: e.type,
        );
      case 429:
        return RateLimitException(
          message ?? _rateLimit,
          code: parsed.code,
          cause: e.type,
        );
      default:
        if (status != null && status >= 500) {
          return ServerException(
            message ?? _server,
            statusCode: status,
            code: parsed.code,
            cause: e.type,
          );
        }
        return UnknownException(
          message ?? fallback ?? _generic,
          statusCode: status,
          code: parsed.code,
          cause: e.type,
        );
    }
  }

  /// Normaliza cualquier error sin envolver [AppException] existente.
  static AppException fromObject(Object error, {String? fallback}) {
    if (error is AppException) return error;
    if (error is DioException) return fromDio(error, fallback: fallback);
    return UnknownException(
      fallback ?? _generic,
      cause: error.runtimeType,
    );
  }

  /// Mensaje público para UI a partir de cualquier error.
  static String publicMessage(Object error, {String? fallback}) {
    return fromObject(error, fallback: fallback).message;
  }

  /// Sanitiza un mensaje ya extraído (HTML, tokens, longitud, controles).
  static String? sanitizePublicMessage(String? message, {String? fallback}) {
    if (message == null || message.trim().isEmpty) {
      return fallback;
    }
    var m = message.trim();
    m = m.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    m = m.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (m.isEmpty) return fallback;
    if (_looksLikeHtml(m)) return fallback;
    if (_looksSensitive(m)) return fallback;
    if (m.length > maxPublicMessageLength) {
      m = '${m.substring(0, maxPublicMessageLength - 1)}…';
    }
    return m;
  }

  static _ParsedBody _parseBody(dynamic data) {
    if (data == null) {
      return const _ParsedBody();
    }

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) {
        return const _ParsedBody();
      }
      if (_looksLikeHtml(trimmed)) {
        return const _ParsedBody();
      }
      return _ParsedBody(message: trimmed);
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      String? message;
      final rawMessage = map['message'];
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        message = rawMessage.trim();
      } else if (map['error'] is String &&
          (map['error'] as String).trim().isNotEmpty) {
        message = (map['error'] as String).trim();
      } else if (map['errorMessage'] is String &&
          (map['errorMessage'] as String).trim().isNotEmpty) {
        message = (map['errorMessage'] as String).trim();
      }
      // Nunca usar Map/List.toString() como mensaje.

      if (message != null && _looksLikeHtml(message)) {
        message = null;
      }

      String? code;
      if (map['error'] != null && map['error'] is! String) {
        // Código tipado no-string: solo si es int/enum simple
        final err = map['error'];
        if (err is num || err is bool) {
          code = err.toString();
        }
      } else if (map['error'] is String && map['message'] != null) {
        code = sanitizePublicMessage(map['error'] as String);
      } else if (map['error'] is String) {
        final err = (map['error'] as String).trim();
        if (err.isNotEmpty && _looksLikeStableErrorCode(err)) {
          code = err.toUpperCase();
          if (message == err) {
            message = null;
          }
        }
      } else if (map['code'] is String || map['code'] is num) {
        code = sanitizePublicMessage(map['code'].toString());
      }

      Map<String, String>? fieldErrors;
      final rawData = map['data'];
      if (rawData is Map) {
        final sanitized = <String, String>{};
        rawData.forEach((k, v) {
          if (v is! String && v is! num && v is! bool) return;
          final key = sanitizePublicMessage(k.toString()) ?? k.toString();
          final value = sanitizePublicMessage(v.toString());
          if (value != null && value.isNotEmpty) {
            sanitized[key] = value;
          }
        });
        if (sanitized.isNotEmpty) fieldErrors = sanitized;
      }

      return _ParsedBody(
        message: message,
        code: code,
        fieldErrors: fieldErrors,
      );
    }

    // Listas u otros: no exponer crudo.
    return const _ParsedBody();
  }

  static bool _looksLikeStableErrorCode(String value) {
    return RegExp(r'^[A-Z][A-Z0-9_]+$').hasMatch(value.trim().toUpperCase());
  }

  static bool _looksLikeHtml(String value) {
    final lower = value.toLowerCase();
    return lower.contains('<html') ||
        lower.contains('<!doctype') ||
        lower.contains('<body') ||
        (lower.contains('<') && lower.contains('</'));
  }

  static bool _looksSensitive(String value) {
    final lower = value.toLowerCase();
    return lower.contains('bearer ') ||
        lower.contains('authorization') ||
        lower.contains('password') ||
        lower.contains('jwt') ||
        lower.contains('stack trace') ||
        lower.contains('#0 ') ||
        lower.contains('dart:');
  }
}

class _ParsedBody {
  const _ParsedBody({this.message, this.code, this.fieldErrors});

  final String? message;
  final String? code;
  final Map<String, String>? fieldErrors;
}
