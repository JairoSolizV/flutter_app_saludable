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
    return _authenticate(() => _remoteDataSource.login(email, password));
  }

  Future<bool> register(String nombre, String apellido, String email, String password, String telefono, {int? rolId}) async {
    return _authenticate(() => _remoteDataSource.register(nombre, apellido, email, password, telefono, rolId: rolId));
  }

  Future<bool> _authenticate(Future<User> Function() authMethod) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await authMethod();
      // Guardar usuario y token localmente
      await _localRepository.saveUser(user);
      _currentUser = user; 
      
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
