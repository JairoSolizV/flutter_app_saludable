import 'package:flutter_app_saludable/core/utils/app_logger.dart';

import 'flutter_secure_storage_gateway.dart';
import 'secure_storage_exception.dart';
import 'secure_storage_gateway.dart';
import 'token_store.dart';

/// Clave estable y específica de la app para el JWT de sesión.
const String kNutrilifeJwtStorageKey = 'nutrilife_club.auth.jwt';

/// Implementación de [TokenStore] con flutter_secure_storage + caché en memoria.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({
    SecureStorageGateway? storage,
    this.storageKey = kNutrilifeJwtStorageKey,
  }) : _storage = storage ?? FlutterSecureStorageGateway();

  final SecureStorageGateway _storage;
  final String storageKey;

  String? _cachedToken;
  bool _initialized = false;
  Future<void>? _initializeFuture;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() {
    if (_initialized) {
      return Future.value();
    }
    return _initializeFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    try {
      final value = await _storage.read(key: storageKey);
      _cachedToken = _normalize(value);
      _initialized = true;
      logDebug('[TokenStore] Almacenamiento seguro inicializado');
    } catch (e) {
      _initializeFuture = null;
      logDebug('[TokenStore] No se pudo inicializar el almacenamiento seguro');
      throw SecureStorageException(
        'No se pudo inicializar el almacenamiento seguro',
        cause: e,
      );
    }
  }

  @override
  String? getToken() {
    if (!_initialized) {
      throw StateError(
        'TokenStore no inicializado. Llama a initialize() antes de getToken().',
      );
    }
    return _cachedToken;
  }

  @override
  Future<void> saveToken(String token) async {
    final normalized = _normalize(token);
    if (normalized == null) {
      throw ArgumentError('El token de sesión no puede estar vacío');
    }
    if (!_initialized) {
      await initialize();
    }
    try {
      await _storage.write(key: storageKey, value: normalized);
      _cachedToken = normalized;
      logDebug('[TokenStore] Token de sesión guardado');
    } catch (e) {
      logDebug('[TokenStore] Falló el guardado del token de sesión');
      throw SecureStorageException(
        'No se pudo guardar el token de sesión',
        cause: e,
      );
    }
  }

  @override
  Future<void> clearToken() async {
    if (!_initialized) {
      await initialize();
    }
    try {
      await _storage.delete(key: storageKey);
      _cachedToken = null;
      logDebug('[TokenStore] Token de sesión eliminado');
    } catch (e) {
      // Aun si falla la persistencia, limpiamos memoria para no reutilizar JWT.
      _cachedToken = null;
      logDebug('[TokenStore] Falló la eliminación persistente del token');
      throw SecureStorageException(
        'No se pudo eliminar el token de sesión',
        cause: e,
      );
    }
  }

  String? _normalize(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}
