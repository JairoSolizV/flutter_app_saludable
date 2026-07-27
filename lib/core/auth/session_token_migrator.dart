import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import 'package:flutter_app_saludable/domain/repositories/user_repository.dart';

import 'secure_storage_exception.dart';
import 'token_store.dart';

/// Migra JWT legacy desde SQLite hacia [TokenStore] una sola vez.
///
/// Idempotente y segura ante fallos: si no se puede escribir en secure storage,
/// no borra el token de SQLite.
class SessionTokenMigrator {
  SessionTokenMigrator({
    required TokenStore tokenStore,
    required UserRepository userRepository,
  })  : _tokenStore = tokenStore,
        _userRepository = userRepository;

  final TokenStore _tokenStore;
  final UserRepository _userRepository;

  /// Ejecuta la migración si corresponde.
  Future<void> migrateIfNeeded() async {
    if (!_tokenStore.isInitialized) {
      await _tokenStore.initialize();
    }

    final secureToken = _tokenStore.getToken();
    if (secureToken != null && secureToken.isNotEmpty) {
      // Secure ya es la fuente de verdad: solo limpiar residuo SQLite.
      await _userRepository.clearPersistedToken();
      logDebug(
          '[TokenMigration] Secure storage ya tenía token; SQLite limpiado');
      return;
    }

    final legacyToken = await _userRepository.readLegacyToken();
    if (legacyToken == null || legacyToken.isEmpty) {
      logDebug('[TokenMigration] Sin token legacy que migrar');
      return;
    }

    try {
      await _tokenStore.saveToken(legacyToken);
    } on SecureStorageException {
      logDebug('[TokenMigration] Falló la migración de sesión legacy');
      rethrow;
    } catch (e) {
      logDebug('[TokenMigration] Falló la migración de sesión legacy');
      throw SecureStorageException(
        'Falló la migración de sesión legacy',
        cause: e,
      );
    }

    // Solo tras confirmación de escritura exitosa (saveToken no lanzó).
    await _userRepository.clearPersistedToken();
    logDebug('[TokenMigration] Token legacy migrado y SQLite limpiado');
  }
}
