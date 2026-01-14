import '../entities/user.dart';

abstract class UserRepository {
  Future<User?> getUser(String id);
  Future<void> saveUser(User user);
  Future<void> updateUser(User user);
  Future<void> logout();
}
