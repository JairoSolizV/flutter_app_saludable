/// Jerarquía de errores de aplicación (mensajes seguros para UI).
///
/// Nunca incluir JWT, Authorization, contraseñas ni payloads sensibles.
sealed class AppException implements Exception {
  AppException(
    this.message, {
    this.statusCode,
    this.code,
    this.cause,
    this.handledGlobally = false,
  });

  /// Mensaje público para el usuario.
  final String message;

  /// HTTP status si aplica.
  final int? statusCode;

  /// Código funcional opcional (p. ej. dominio backend).
  final String? code;

  /// Causa interna (solo para logs seguros, no para UI).
  final Object? cause;

  /// True si la UI global (sesión expirada) ya mostró feedback.
  final bool handledGlobally;

  /// Si la pantalla/provider local debe mostrar SnackBar/dialog.
  bool get shouldPresentToUser => !handledGlobally;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.cause, super.handledGlobally});
}

class TimeoutException extends AppException {
  TimeoutException(super.message, {super.cause, super.handledGlobally});
}

class UnauthorizedException extends AppException {
  UnauthorizedException(
    super.message, {
    super.statusCode = 401,
    super.code,
    super.cause,
    super.handledGlobally,
  });
}

/// 401 de endpoint protegido ya invalidó sesión y mostró feedback global.
class SessionExpiredException extends UnauthorizedException {
  SessionExpiredException([
    super.message = 'Tu sesión expiró. Inicia sesión nuevamente.',
  ]) : super(handledGlobally: true);
}

class ForbiddenException extends AppException {
  ForbiddenException(
    super.message, {
    super.statusCode = 403,
    super.code,
    super.cause,
    super.handledGlobally,
  });
}

/// Credenciales correctas, pero el correo no está verificado (OTP pendiente).
class EmailNotVerifiedException extends ForbiddenException {
  static const String errorCode = 'EMAIL_NOT_VERIFIED';

  EmailNotVerifiedException([
    super.message = 'Debes verificar tu correo para continuar.',
  ]) : super(statusCode: 403, code: errorCode);
}

class NotFoundException extends AppException {
  NotFoundException(
    super.message, {
    super.statusCode = 404,
    super.code,
    super.cause,
    super.handledGlobally,
  });
}

class ValidationException extends AppException {
  ValidationException(
    super.message, {
    super.statusCode = 400,
    super.code,
    super.cause,
    super.handledGlobally,
    this.fieldErrors,
  });

  final Map<String, String>? fieldErrors;
}

/// OTP de recuperación inválido, expirado o bloqueado.
class ResetCodeInvalidException extends ValidationException {
  static const String errorCode = 'RESET_CODE_INVALID';
  static const String defaultMessage = 'Código inválido o expirado.';

  ResetCodeInvalidException([
    super.message = defaultMessage,
  ]) : super(statusCode: 400, code: errorCode);
}

/// Token de reset inválido, expirado o ya utilizado.
class ResetTokenInvalidException extends ValidationException {
  static const String errorCode = 'RESET_TOKEN_INVALID';
  static const String defaultMessage =
      'El enlace de recuperación es inválido o expiró. Solicita un nuevo código.';

  ResetTokenInvalidException([
    super.message = defaultMessage,
  ]) : super(statusCode: 400, code: errorCode);
}

/// El socio debe tener un combo ENTREGADO hoy antes de registrar asistencia.
class ComboRequiredException extends ValidationException {
  static const String errorCode = 'COMBO_REQUIRED';
  static const String defaultMessage =
      'El socio no ha consumido ningún Combo antes de registrar asistencia.';

  ComboRequiredException([
    super.message = defaultMessage,
  ]) : super(statusCode: 400, code: errorCode);
}

class ConflictException extends AppException {
  ConflictException(
    super.message, {
    super.statusCode = 409,
    super.code,
    super.cause,
    super.handledGlobally,
  });
}

class RateLimitException extends AppException {
  RateLimitException(
    super.message, {
    super.statusCode = 429,
    super.code,
    super.cause,
    super.handledGlobally,
  });
}

/// Cooldown de reenvío OTP EMAIL_VERIFICATION (backend autoritativo).
class OtpResendCooldownException extends RateLimitException {
  static const String errorCode = 'OTP_RESEND_COOLDOWN';
  static const String defaultMessage =
      'Espera unos segundos antes de solicitar otro código.';

  OtpResendCooldownException({
    required this.retryAfterSeconds,
    String? message,
  }) : super(
          message ?? defaultMessage,
          statusCode: 429,
          code: errorCode,
        );

  final int retryAfterSeconds;
}

class ServerException extends AppException {
  ServerException(
    super.message, {
    super.statusCode,
    super.code,
    super.cause,
    super.handledGlobally,
  });
}

/// Rol backend ADMIN: la app móvil no expone panel administrativo.
class AdminMobileNotSupportedException extends AppException {
  static const String errorCode = 'ADMIN_MOBILE_NOT_SUPPORTED';
  static const String defaultMessage =
      'La app móvil no está disponible para administradores. Usa el panel web.';

  AdminMobileNotSupportedException([
    super.message = defaultMessage,
  ]) : super(code: errorCode);
}

class StorageException extends AppException {
  StorageException(super.message, {super.cause, super.handledGlobally});
}

class UnknownException extends AppException {
  UnknownException(
    super.message, {
    super.statusCode,
    super.code,
    super.cause,
    super.handledGlobally,
  });
}

/// True si la UI local debe mostrar el error (no fue un 401 global).
bool shouldPresentErrorToUser(Object error) {
  if (error is AppException) return error.shouldPresentToUser;
  return true;
}
