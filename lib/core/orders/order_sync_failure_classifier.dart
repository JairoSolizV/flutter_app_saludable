import '../errors/app_exceptions.dart';
import '../errors/error_mapper.dart';
import 'order_sync_backend_codes.dart';

enum OrderSyncFailureAction {
  retryable,
  authPause,
  permanent,
}

class OrderSyncFailureClassification {
  const OrderSyncFailureClassification(
    this.action, {
    this.errorCode,
    this.errorMessage,
  });

  final OrderSyncFailureAction action;
  final String? errorCode;
  final String? errorMessage;

  bool get isRetryable => action == OrderSyncFailureAction.retryable;

  bool get isAuthPause => action == OrderSyncFailureAction.authPause;

  bool get isPermanent => action == OrderSyncFailureAction.permanent;
}

/// Clasifica errores de sync por tipo + status + code (sin parsear mensajes).
class OrderSyncFailureClassifier {
  OrderSyncFailureClassifier._();

  static OrderSyncFailureClassification classify(Object error) {
    final app = error is AppException ? error : ErrorMapper.fromObject(error);
    final code = _normalizeCode(app.code);
    final message = ErrorMapper.publicMessage(app);

    if (app is SessionExpiredException ||
        (app is AppException && app.handledGlobally)) {
      return const OrderSyncFailureClassification(
        OrderSyncFailureAction.authPause,
      );
    }

    if (app is UnauthorizedException) {
      return const OrderSyncFailureClassification(
        OrderSyncFailureAction.authPause,
      );
    }

    if (app is ForbiddenException) {
      return const OrderSyncFailureClassification(
        OrderSyncFailureAction.authPause,
      );
    }

    if (app is NetworkException ||
        app is TimeoutException ||
        app is ServerException ||
        app is RateLimitException) {
      return const OrderSyncFailureClassification(
        OrderSyncFailureAction.retryable,
      );
    }

    if (app is ConflictException) {
      if (code == OrderSyncBackendCodes.conflict) {
        return const OrderSyncFailureClassification(
          OrderSyncFailureAction.retryable,
        );
      }
      return OrderSyncFailureClassification(
        OrderSyncFailureAction.permanent,
        errorCode: code ?? OrderSyncBackendCodes.clientIdConflict,
        errorMessage: message,
      );
    }

    if (app is ValidationException) {
      if (code != null && OrderSyncBackendCodes.permanentCodes.contains(code)) {
        return OrderSyncFailureClassification(
          OrderSyncFailureAction.permanent,
          errorCode: code,
          errorMessage: message,
        );
      }
      return OrderSyncFailureClassification(
        OrderSyncFailureAction.permanent,
        errorCode: code,
        errorMessage: message,
      );
    }

    if (app is NotFoundException) {
      if (code != null &&
          OrderSyncBackendCodes.notFoundPermanentCodes.contains(code)) {
        return OrderSyncFailureClassification(
          OrderSyncFailureAction.permanent,
          errorCode: code,
          errorMessage: message,
        );
      }
      return OrderSyncFailureClassification(
        OrderSyncFailureAction.permanent,
        errorCode: code,
        errorMessage: message,
      );
    }

    final status = app.statusCode;
    if (status == 400 || status == 404 || status == 409) {
      return OrderSyncFailureClassification(
        OrderSyncFailureAction.permanent,
        errorCode: code,
        errorMessage: message,
      );
    }

    if (status != null && status >= 500) {
      return const OrderSyncFailureClassification(
        OrderSyncFailureAction.retryable,
      );
    }

    return const OrderSyncFailureClassification(
      OrderSyncFailureAction.retryable,
    );
  }

  static String? _normalizeCode(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    return code.trim().toUpperCase();
  }
}
