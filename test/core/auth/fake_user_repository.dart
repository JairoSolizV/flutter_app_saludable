import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_app_saludable/domain/repositories/user_repository.dart';

class FakeUserRepository implements UserRepository {
  User? current;
  String? legacyToken;
  int getCurrentUserCalls = 0;
  int clearPersistedTokenCalls = 0;
  int readLegacyTokenCalls = 0;
  int saveUserCalls = 0;
  int logoutCalls = 0;

  @override
  Future<void> clearPersistedToken() async {
    clearPersistedTokenCalls++;
    legacyToken = null;
    if (current != null) {
      current = current!.withoutToken();
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    getCurrentUserCalls++;
    return current;
  }

  @override
  Future<User?> getUser(String id) async {
    if (current?.id == id) return current;
    return null;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    current = null;
    legacyToken = null;
  }

  @override
  Future<String?> readLegacyToken() async {
    readLegacyTokenCalls++;
    final t = legacyToken?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  @override
  Future<void> saveUser(User user) async {
    saveUserCalls++;
    // Simula persistencia real: nunca guarda JWT.
    current = user.withoutToken();
    legacyToken = null;
  }

  @override
  Future<void> updateUser(User user) async {
    current = user.withoutToken();
  }
}
