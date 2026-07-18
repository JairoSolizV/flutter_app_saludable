import 'package:flutter_app_saludable/core/utils/app_logger.dart';

/// Contrato para estado en memoria ligado a una sesión autenticada.
abstract class SessionScopedState {
  /// Limpia listas, errores, loading y selecciones de la sesión actual.
  ///
  /// No debe borrar pedidos offline persistidos en SQLite.
  Future<void> clearSessionState();
}

/// Registra callbacks / providers scoped a sesión y los limpia en un solo lugar.
///
/// Usado en logout manual, expiración 401 y cambio de cuenta (sin DI general).
class SessionStateResetter {
  final List<SessionScopedState> _scoped = [];
  final List<Future<void> Function()> _extraClears = [];

  void register(SessionScopedState state) {
    if (!_scoped.contains(state)) {
      _scoped.add(state);
    }
  }

  void registerClear(Future<void> Function() clear) {
    _extraClears.add(clear);
  }

  void unregister(SessionScopedState state) {
    _scoped.remove(state);
  }

  /// Limpia todos los estados de sesión registrados (una pasada).
  Future<void> clearAll() async {
    for (final state in List<SessionScopedState>.from(_scoped)) {
      try {
        await state.clearSessionState();
      } catch (_) {
        logDebug(
            '[SessionStateResetter] Falló clearSessionState de un provider');
      }
    }
    for (final clear in List<Future<void> Function()>.from(_extraClears)) {
      try {
        await clear();
      } catch (_) {
        logDebug('[SessionStateResetter] Falló clear extra de sesión');
      }
    }
  }
}
