import 'package:flutter/material.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _repository;
  User? _currentUser;
  bool _isLoading = false;

  UserProvider(this._repository);

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  Future<void> loadUser(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _repository.getUser(userId);
    } catch (e) {
      print('Error loading user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> updateUserProfile({String? name, String? email, String? phone}) async {
    if (_currentUser == null) return;

    final updatedUser = _currentUser!.copyWith(
      name: name,
      email: email,
      phone: phone,
    );

    try {
      await _repository.updateUser(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }
}
