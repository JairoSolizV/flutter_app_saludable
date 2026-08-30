import '../errors/app_exceptions.dart';

/// Mensajes UX para flujo offline de pedidos SOCIO.
class OrderOfflineMessages {
  OrderOfflineMessages._();

  static const savedPending =
      'Pedido guardado. Se enviará cuando recuperes conexión.';

  static const sentSynced = 'Pedido enviado al club correctamente.';

  static const offlineEmptyTitle = 'Sin conexión';

  static const offlineEmptyBody = 'No pudimos actualizar tus pedidos.';

  static const localPendingBanner =
      'Se enviará automáticamente cuando recuperes internet.';

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
