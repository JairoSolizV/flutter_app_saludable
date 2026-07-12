import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../../data/datasources/remote/auth_remote_data_source.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRemoteDataSource _remoteDataSource;
  final UserRepository _localRepository;
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _requiresVerification = false;

  AuthProvider(this._remoteDataSource, this._localRepository);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get requiresVerification => _requiresVerification;

  User? _currentUser;
  User? get currentUser => _currentUser;

  /// Limpiar mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Resetear el flag de verificación
  void clearVerificationFlag() {
    _requiresVerification = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    return _authenticate(() => _remoteDataSource.login(email, password));
  }

  Future<bool> register(String nombre, String apellido, String email, String password, String telefono, {int? rolId}) async {
    _isLoading = true;
    _errorMessage = null;
    _requiresVerification = false;
    notifyListeners();

    try {
      final user = await _remoteDataSource.register(nombre, apellido, email, password, telefono, rolId: rolId);
      logDebug('[DEBUG AUTH_PROVIDER] Usuario registrado:');
      logDebug('[DEBUG AUTH_PROVIDER]   - id: ${user.id}');
      logDebug('[DEBUG AUTH_PROVIDER]   - email: ${user.email}');

      // Guardar usuario localmente (incluso sin verificar, para tener el token)
      logDebug('[DEBUG AUTH_PROVIDER] Limpiando BD local antes de guardar nuevo usuario...');
      await _localRepository.logout();
      await _localRepository.saveUser(user);
      _currentUser = user;

      // El backend siempre requiere verificación para nuevos registros
      _requiresVerification = true;
      
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

  Future<bool> checkEmailExists(String email) async {
    try {
      return await _remoteDataSource.checkEmailExists(email);
    } catch (e) {
      logDebug('[DEBUG AUTH_PROVIDER] Error checking email existence: $e');
      return false;
    }
  }

  /// Verificar correo electrónico con código OTP
  Future<bool> verifyEmail(String email, String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final verified = await _remoteDataSource.verifyEmail(email, code);
      
      if (verified) {
        _requiresVerification = false;
        logDebug('[DEBUG AUTH_PROVIDER] Correo verificado exitosamente para: $email');
      } else {
        _errorMessage = 'Código inválido o expirado. Intenta de nuevo.';
      }

      _isLoading = false;
      notifyListeners();
      return verified;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reenviar código de verificación
  Future<bool> resendCode(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _remoteDataSource.resendVerificationCode(email);
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _authenticate(Future<User> Function() authMethod) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await authMethod();
      logDebug('[DEBUG AUTH_PROVIDER] Usuario autenticado:');
      logDebug('[DEBUG AUTH_PROVIDER]   - id: ${user.id}');
      logDebug('[DEBUG AUTH_PROVIDER]   - email: ${user.email}');
      logDebug('[DEBUG AUTH_PROVIDER]   - token: ${user.token != null ? "PRESENTE (${user.token!.length} chars)" : "NULL"}');
      if (user.token != null && user.token!.length > 20) {
        logDebug('[DEBUG AUTH_PROVIDER]   - token preview: ${user.token!.substring(0, 20)}...');
      }
      
      // SOLUCIÓN: Limpiar BD local antes de guardar el nuevo usuario
      // Esto asegura que solo haya un usuario en la BD local (single-user app)
      // y evita problemas con tokens expirados de sesiones anteriores
      logDebug('[DEBUG AUTH_PROVIDER] Limpiando BD local antes de guardar nuevo usuario...');
      await _localRepository.logout(); // Limpia todos los usuarios viejos
      logDebug('[DEBUG AUTH_PROVIDER] BD local limpiada correctamente');
      
      // Guardar usuario y token localmente
      await _localRepository.saveUser(user);
      logDebug('[DEBUG AUTH_PROVIDER] Usuario guardado en BD local');
      
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
      logDebug('[DEBUG AUTH_PROVIDER] Starting syncProfile()');
      
      final fetchedUser = await _remoteDataSource.getMe();
      
      logDebug('[DEBUG AUTH_PROVIDER] Fetched user from getMe():');
      logDebug('[DEBUG AUTH_PROVIDER]   - id: ${fetchedUser.id}');
      logDebug('[DEBUG AUTH_PROVIDER]   - name: ${fetchedUser.name}');
      logDebug('[DEBUG AUTH_PROVIDER]   - phone: ${fetchedUser.phone}');
      logDebug('[DEBUG AUTH_PROVIDER]   - email: ${fetchedUser.email}');
      
      // Preservar el token actual si el endpoint no lo devuelve (caso getMe)
      String? tokenToSave = fetchedUser.token;
      if (tokenToSave == null && _currentUser != null) {
        tokenToSave = _currentUser!.token;
      }
      
      final userToSave = fetchedUser.copyWith(token: tokenToSave);
      
      logDebug('[DEBUG AUTH_PROVIDER] User after copyWith (with token):');
      logDebug('[DEBUG AUTH_PROVIDER]   - phone: ${userToSave.phone}');
      logDebug('[DEBUG AUTH_PROVIDER]   - token: ${userToSave.token != null ? "present" : "null"}');

      await _localRepository.saveUser(userToSave);
      
      logDebug('[DEBUG AUTH_PROVIDER] User saved to local repository');
      
      _currentUser = userToSave;
      notifyListeners();
      
      logDebug('[DEBUG AUTH_PROVIDER] syncProfile completed successfully');
    } catch (e) {
      logDebug('[DEBUG AUTH_PROVIDER] Error syncing profile: $e');
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

      logDebug('[DEBUG AUTH_PROVIDER] Updating profile for user ${updatedUser.id}');
      
      // 1. Llamada al Backend
      final resultUser = await _remoteDataSource.updateUser(updatedUser);
      
      // 2. Actualizar localmente
      // El backend devuelve el usuario actualizado (o parseamos el que enviamos si confíamos)
      // Aseguramos mantener el token
      final userToSave = resultUser.copyWith(token: _currentUser!.token);
      
      await _localRepository.saveUser(userToSave);
      _currentUser = userToSave;
      
      logDebug('[DEBUG AUTH_PROVIDER] Profile updated successfully');
    } catch (e) {
      logDebug('[DEBUG AUTH_PROVIDER] Error updating profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
      logDebug('[DEBUG AUTH_PROVIDER] logout() - Iniciando cierre de sesión');
      _currentUser = null;
      _requiresVerification = false;
      await _localRepository.logout();
      logDebug('[DEBUG AUTH_PROVIDER] logout() - Sesión cerrada, usuario limpiado');
      notifyListeners();
  }
}
