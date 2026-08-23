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

class ServerException extends AppException {
  ServerException(
    super.message, {
    super.statusCode,
    super.code,
    super.cause,
    super.handledGlobally,
  });
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
