/// Abstracción mínima sobre Keychain/Keystore para poder testear sin hardware.
abstract class SecureStorageGateway {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}
