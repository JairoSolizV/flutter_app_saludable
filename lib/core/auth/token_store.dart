/// Almacén de JWT con caché en memoria.
///
/// Contrato:
/// - [initialize] lee el almacenamiento seguro una sola vez.
/// - Tras inicializar, [getToken] es síncrono y no hace I/O.
/// - [saveToken] / [clearToken] actualizan persistencia y memoria.
abstract class TokenStore {
  /// True cuando [initialize] completó con éxito al menos una vez.
  bool get isInitialized;

  /// Hidrata la caché en memoria desde el almacenamiento seguro.
  ///
  /// Seguro ante llamadas duplicadas (idempotente).
  Future<void> initialize();

  /// Token en memoria. Requiere [isInitialized] == true.
  ///
  /// No realiza I/O. Devuelve null si no hay sesión.
  String? getToken();

  /// Persiste y cachea el JWT. No registrar el valor en logs.
  Future<void> saveToken(String token);

  /// Elimina JWT de persistencia y memoria.
  Future<void> clearToken();
}
