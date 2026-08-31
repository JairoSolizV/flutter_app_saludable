import '../errors/app_exceptions.dart';
import 'order_sync_backend_codes.dart';

/// Mensajes UX para flujo offline de pedidos SOCIO.
class OrderOfflineMessages {
  OrderOfflineMessages._();

  static const savedPending =
      'Pedido guardado. Se enviará cuando recuperes conexión.';

  static const sentSynced = 'Pedido enviado al club correctamente.';

  static const sendFailed =
      'No se pudo enviar el pedido. Revisa tus pedidos para ver el motivo.';

  static const offlineEmptyTitle = 'Sin conexión';

  static const offlineEmptyBody = 'No pudimos actualizar tus pedidos.';

  static const orderRequiresConnection =
      'Sin conexión. Conéctate a internet para realizar tu pedido.';

  static const clubDataRequiresConnection =
      'Sin conexión. Conéctate a internet para cargar los datos de tu club.';

  static const localPendingBanner =
      'Se enviará automáticamente cuando recuperes internet.';

  static String failedOrderMessage(String? code) {
    switch (code?.trim().toUpperCase()) {
      case OrderSyncBackendCodes.membershipInactive:
      case OrderSyncBackendCodes.membershipUnavailable:
        return 'Tu membresía ya no está activa. Contacta al anfitrión.';
      case OrderSyncBackendCodes.clubInactive:
      case OrderSyncBackendCodes.clubUnavailable:
        return 'Este club ya no acepta pedidos.';
      case OrderSyncBackendCodes.productUnavailable:
        return 'Un producto de tu pedido ya no está disponible.';
      case OrderSyncBackendCodes.comboUnavailable:
        return 'Un combo de tu pedido ya no está disponible.';
      case OrderSyncBackendCodes.optionInvalid:
        return 'Una opción seleccionada ya no está disponible.';
      case OrderSyncBackendCodes.invalidQuantity:
      case OrderSyncBackendCodes.invalidRequest:
        return 'El pedido ya no es válido. Revisa el menú y vuelve a intentarlo.';
      case OrderSyncBackendCodes.clientIdConflict:
        return 'No se pudo enviar este pedido. Si el problema continúa, contacta soporte.';
      default:
        return 'No se pudo enviar el pedido. Revisa el menú y vuelve a intentarlo.';
    }
  }

  static bool isLikelyNetworkError(Object? error) {
    if (error is NetworkException || error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('network') ||
        text.contains('networkerror') ||
        text.contains('conexión') ||
        text.contains('conexion') ||
        text.contains('internet') ||
        text.contains('socket');
  }

  static String friendlyLoadError(Object error) {
    if (isLikelyNetworkError(error)) {
      return offlineEmptyBody;
    }
    return error.toString().replaceAll('Exception: ', '');
  }
}
