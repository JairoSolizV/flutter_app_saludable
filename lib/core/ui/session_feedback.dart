import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/router/app_router.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';

/// Feedback de sesión (SnackBar) sin BuildContext de pantallas profundas.
class SessionFeedback {
  SessionFeedback._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static const expiredMessage = 'Tu sesión expiró. Inicia sesión nuevamente.';

  static bool _expiredMessageShown = false;

  /// True si el mensaje de esta expiración ya se mostró (tests).
  static bool get expiredMessageShownForTest => _expiredMessageShown;

  /// Muestra el mensaje de expiración como máximo una vez por ciclo de expiración.
  ///
  /// Solo marca el gate si el SnackBar se encola realmente. Si el messenger
  /// aún no existe, no consume el intento.
  static void showSessionExpiredMessage() {
    if (_expiredMessageShown) return;
    final messenger = messengerKey.currentState;
    if (messenger == null) {
      logDebug('[SessionFeedback] Sin ScaffoldMessenger; mensaje diferido');
      return;
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text(expiredMessage)),
      );
    _expiredMessageShown = true;
  }

  /// Permite volver a mostrar el mensaje en una futura expiración.
  static void resetExpiredMessageGate() {
    _expiredMessageShown = false;
  }
}

/// Destinos públicos donde no debe forzarse redirección por 401.
bool isPublicNavigationLocation(String location) {
  final path = location.split('?').first;
  const public = {
    '/',
    '/guest-home',
    '/guest-catalog',
    '/guest-map',
    '/login',
    '/register',
    '/verify-email',
  };
  return public.contains(path);
}

/// Navega al flujo público sin dejar pantallas autenticadas en el stack.
Future<void> navigateToPublicAfterSessionExpiry() async {
  try {
    final location = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (isPublicNavigationLocation(location)) {
      logDebug('[SessionNav] Ya en flujo público; skip redirect');
      return;
    }
    appRouter.go('/guest-home');
  } catch (_) {
    logDebug('[SessionNav] No se pudo navegar tras expiración');
  }
}
