import '../entities/user.dart';

abstract class UserRepository {
  Future<User?> getUser(String id);
  Future<void> saveUser(User user);
  Future<void> updateUser(User user);
  Future<void> logout();
  Future<User?> getCurrentUser();

  /// Lee el JWT legacy en la columna SQLite `users.token` (una sola consulta).
  /// Usado solo por la migración hacia secure storage.
  Future<String?> readLegacyToken();

  /// Pone en null la columna `users.token` sin borrar el perfil.
  Future<void> clearPersistedToken();
}
