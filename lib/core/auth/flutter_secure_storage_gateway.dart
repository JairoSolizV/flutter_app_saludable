import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_gateway.dart';

/// Adaptador de producción sobre [FlutterSecureStorage] (v9.x).
///
/// Opciones:
/// - Android: EncryptedSharedPreferences (API estable en 9.2.x).
/// - iOS: Keychain con accesibilidad first_unlock_this_device (sesión
///   persistente tras reinicio, sin exigir desbloqueo biométrico continuo).
class FlutterSecureStorageGateway implements SecureStorageGateway {
  FlutterSecureStorageGateway({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}
