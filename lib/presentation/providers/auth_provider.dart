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
  Future<void> syncProfile() async {
    try {
      print('[DEBUG AUTH_PROVIDER] Starting syncProfile()');
      
      final fetchedUser = await _remoteDataSource.getMe();
      
      print('[DEBUG AUTH_PROVIDER] Fetched user from getMe():');
      print('[DEBUG AUTH_PROVIDER]   - id: ${fetchedUser.id}');
      print('[DEBUG AUTH_PROVIDER]   - name: ${fetchedUser.name}');
      print('[DEBUG AUTH_PROVIDER]   - phone: ${fetchedUser.phone}');
      print('[DEBUG AUTH_PROVIDER]   - email: ${fetchedUser.email}');
      
      // Preservar el token actual si el endpoint no lo devuelve (caso getMe)
      String? tokenToSave = fetchedUser.token;
      if (tokenToSave == null && _currentUser != null) {
        tokenToSave = _currentUser!.token;
      }
      
      final userToSave = fetchedUser.copyWith(token: tokenToSave);
      
      print('[DEBUG AUTH_PROVIDER] User after copyWith (with token):');
      print('[DEBUG AUTH_PROVIDER]   - phone: ${userToSave.phone}');
      print('[DEBUG AUTH_PROVIDER]   - token: ${userToSave.token != null ? "present" : "null"}');

      await _localRepository.saveUser(userToSave);
      
      print('[DEBUG AUTH_PROVIDER] User saved to local repository');
      
      _currentUser = userToSave;
      notifyListeners();
      
      print('[DEBUG AUTH_PROVIDER] syncProfile completed successfully');
    } catch (e) {
      print('[DEBUG AUTH_PROVIDER] Error syncing profile: $e');
      // No lanzamos error para no interrumpir UI, solo log
    }
  }

  Future<void> updateProfile({
    String? name, 
    String? phone, 
    String? birthDate,
    Map<String, dynamic>? socialMedia,
  }) async {
    if (_currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final updatedUser = _currentUser!.copyWith(
        name: name,
        phone: phone,
        birthDate: birthDate,
        socialMedia: socialMedia,
      );

      print('[DEBUG AUTH_PROVIDER] Updating profile for user ${updatedUser.id}');
      
      // 1. Llamada al Backend
      final resultUser = await _remoteDataSource.updateUser(updatedUser);
      
      // 2. Actualizar localmente
      // El backend devuelve el usuario actualizado (o parseamos el que enviamos si confíamos)
      // Aseguramos mantener el token
      final userToSave = resultUser.copyWith(token: _currentUser!.token);
      
      await _localRepository.saveUser(userToSave);
      _currentUser = userToSave;
      
      print('[DEBUG AUTH_PROVIDER] Profile updated successfully');
    } catch (e) {
      print('[DEBUG AUTH_PROVIDER] Error updating profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
      await _localRepository.logout();
      notifyListeners();
  }
}
