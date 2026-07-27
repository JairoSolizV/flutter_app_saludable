import 'package:flutter/foundation.dart';

/// Registra mensajes SOLO en builds de depuración.
///
/// En release no hace nada, evitando exponer datos sensibles (tokens, JWT)
/// en los logs del sistema (Logcat / System Logs). Ver VULN-FL-02.
void logDebug(Object? message) {
  if (kDebugMode) {
    debugPrint(message?.toString());
  }
}
