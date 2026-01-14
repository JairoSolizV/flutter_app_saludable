import 'package:flutter/material.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../../data/datasources/remote/auth_remote_data_source.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRemoteDataSource _remoteDataSource;
  final UserRepository _localRepository;
  
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._remoteDataSource, this._localRepository);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  User? _currentUser;
  User? get currentUser => _currentUser;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _remoteDataSource.login(email, password);
      // Guardar usuario y token localmente
      await _localRepository.saveUser(user);
      _currentUser = user; // Set current user
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
      await _localRepository.logout();
      notifyListeners();
  }
}
