import 'dart:async';

import 'package:flutter_app_saludable/core/auth/session_status.dart';
import 'package:flutter_app_saludable/core/auth/token_store.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';

/// Coordina invalidación de sesión ante 401 sin acoplar Dio ↔ AuthProvider ↔ UI.
///
/// Cableado típico (sin ciclo):
/// `TokenStore` ← `SessionExpirationHandler` ← callbacks de Auth + navegación
/// `ApiClient` solo conoce este handler (no AuthProvider ni GoRouter).
class SessionExpirationHandler {
  SessionExpirationHandler({required TokenStore tokenStore})
      : _tokenStore = tokenStore;

  final TokenStore _tokenStore;

  Future<void> Function()? _clearLocalSession;
  Future<void> Function()? _onSessionExpiredUi;

  /// Generación del binding actual; evita que un State viejo haga unbind del nuevo.
  int _bindGeneration = 0;

  Completer<void>? _inFlight;

  /// Permanece true tras un 401 o logout manual hasta [markActive] (nuevo login).
  /// Evita N logout/navegaciones cuando varios 401 llegan en serie o paralelo.
  bool _sessionInvalidated = false;

  /// True si la UI de expiración (nav + snackbar) ya se disparó en este ciclo.
  bool _expirationUiConsumed = false;

  /// Limpieza de providers pendiente porque el 401 llegó antes de [bind].
  bool _pendingProviderClear = false;

  SessionStatus _status = SessionStatus.unknown;
  int _logoutInvocations = 0;
  int _navigationInvocations = 0;

  SessionStatus get status => _status;

  /// True mientras hay invalidación en curso o la sesión ya fue invalidada.
  bool get isInvalidating =>
      _inFlight != null ||
      _status == SessionStatus.expiring ||
      _sessionInvalidated;

  int get logoutInvocationsForTest => _logoutInvocations;
  int get navigationInvocationsForTest => _navigationInvocations;
  int get bindGenerationForTest => _bindGeneration;

  /// Registra callbacks. Devuelve un token de generación para [unbind].
  int bind({
    required Future<void> Function() clearLocalSession,
    required Future<void> Function() onSessionExpiredUi,
  }) {
    final generation = ++_bindGeneration;
    _clearLocalSession = clearLocalSession;
    _onSessionExpiredUi = onSessionExpiredUi;

    if (_pendingProviderClear) {
      _pendingProviderClear = false;
      scheduleMicrotask(() async {
        if (generation != _bindGeneration) return;
        try {
          await _clearLocalSession?.call();
        } catch (_) {
          logDebug(
            '[SessionExpiration] Catch-up clearLocalSession tras bind falló',
          );
        }
      });
    }

    return generation;
  }

  /// Elimina callbacks solo si [generation] es el binding vigente.
  void unbind(int generation) {
    if (generation != _bindGeneration) return;
    _clearLocalSession = null;
    _onSessionExpiredUi = null;
  }

  void markActive() {
    _sessionInvalidated = false;
    _expirationUiConsumed = false;
    _pendingProviderClear = false;
    _status = SessionStatus.active;
  }

  void markGuest() {
    if (_inFlight == null) {
      _status = SessionStatus.guest;
    }
  }

  /// Logout manual: bloquea un 401 tardío (sin otro SnackBar/navegación).
  void markLoggedOut() {
    _sessionInvalidated = true;
    _expirationUiConsumed = true;
    _pendingProviderClear = false;
    _status = SessionStatus.guest;
  }

  /// Single-flight + latch: N llamadas concurrentes/secuenciales → una limpieza.
  Future<void> handleUnauthorized() {
    if (_inFlight != null) {
      return _inFlight!.future;
    }
    if (_sessionInvalidated) {
      return Future.value();
    }

    final completer = Completer<void>();
    _inFlight = completer;
    _sessionInvalidated = true;
    _status = SessionStatus.expiring;

    () async {
      try {
        _logoutInvocations++;

        if (_tokenStore.isInitialized) {
          try {
            await _tokenStore.clearToken();
          } catch (_) {
            logDebug(
              '[SessionExpiration] Falló limpieza de TokenStore durante 401',
            );
          }
        }

        final clear = _clearLocalSession;
        if (clear != null) {
          try {
            await clear();
          } catch (_) {
            logDebug(
              '[SessionExpiration] Falló clearLocalSession durante 401',
            );
          }
        } else {
          _pendingProviderClear = true;
        }

        _status = SessionStatus.expired;

        if (!_expirationUiConsumed) {
          _expirationUiConsumed = true;
          final ui = _onSessionExpiredUi;
          if (ui != null) {
            try {
              _navigationInvocations++;
              await ui();
            } catch (_) {
              logDebug(
                '[SessionExpiration] Callback UI de sesión expirada falló',
              );
            }
          }
        }
      } finally {
        _status = SessionStatus.guest;
        if (!completer.isCompleted) {
          completer.complete();
        }
        _inFlight = null;
      }
    }();

    return completer.future;
  }
}
