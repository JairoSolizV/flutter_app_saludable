import 'package:flutter_app_saludable/core/auth/secure_storage_gateway.dart';

/// Almacenamiento en memoria para tests (sin Keychain/Keystore).
class InMemorySecureStorageGateway implements SecureStorageGateway {
  final Map<String, String> _data = {};
  int readCount = 0;
  int writeCount = 0;
  int deleteCount = 0;
  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;

  @override
  Future<String?> read({required String key}) async {
    readCount++;
    if (failReads) {
      throw StateError('simulated read failure');
    }
    return _data[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writeCount++;
    if (failWrites) {
      throw StateError('simulated write failure');
    }
    _data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    deleteCount++;
    if (failDeletes) {
      throw StateError('simulated delete failure');
    }
    _data.remove(key);
  }

  void seed(String key, String value) {
    _data[key] = value;
  }

  bool containsKey(String key) => _data.containsKey(key);
}
