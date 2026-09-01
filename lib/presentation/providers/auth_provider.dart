import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/core/auth/pending_verification_store.dart';
import 'package:flutter_app_saludable/core/auth/secure_storage_exception.dart';
import 'package:flutter_app_saludable/core/auth/session_expiration_handler.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/auth/session_status.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_app_saludable/core/auth/token_store.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/core/ui/session_feedback.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import 'package:flutter_app_saludable/core/utils/validators.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../../data/datasources/remote/auth_remote_data_source.dart';
import '../../core/auth/google_auth_service.dart';
import '../../core/auth/sqlite_pending_verification_store.dart';

class AuthProvider extends ChangeNotifier implements SessionScopedState {
  final AuthRemoteDataSource _remoteDataSource;
  final UserRepository _localRepository;
  final TokenStore _tokenStore;
  final SessionTokenMigrator _sessionMigrator;
  final SessionExpirationHandler? _sessionExpirationHandler;
  final SessionOwner? _sessionOwner;
  final SessionStateResetter? _sessionStateResetter;
  final PendingVerificationStore _pendingVerificationStore;
  
  final GoogleAuthService _googleAuthService;

  bool _isLoading = false;
  String? _errorMessage;
  bool _requiresVerification = false;
  bool _sessionReady = false;
  SessionStatus _sessionStatus = SessionStatus.unknown;
  String? _passwordResetToken;
  int? _otpResendRetryAfterSeconds;

  /// Mensaje público anti-enumeración (alineado con backend).
  static const String passwordResetRequestMessage =
      'Si el correo está registrado, recibirás un código para restablecer tu contraseña.';

  AuthProvider(
    this._remoteDataSource,
    this._localRepository,
    this._tokenStore, {
    PendingVerificationStore? pendingVerificationStore,
    SessionTokenMigrator? sessionMigrator,
    SessionExpirationHandler? sessionExpirationHandler,
    SessionOwner? sessionOwner,
    SessionStateResetter? sessionStateResetter,
    GoogleAuthService? googleAuthService,
  })  : _pendingVerificationStore =
            pendingVerificationStore ?? InMemoryPendingVerificationStore(),
        _sessionMigrator = sessionMigrator ??
            SessionTokenMigrator(
              tokenStore: _tokenStore,
              userRepository: _localRepository,
            ),
        _sessionExpirationHandler = sessionExpirationHandler,
        _sessionOwner = sessionOwner,
        _sessionStateResetter = sessionStateResetter,
        _googleAuthService = googleAuthService ??
            GoogleAuthService(
              webClientId: kGoogleWebClientId,
            );

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get otpResendRetryAfterSeconds => _otpResendRetryAfterSeconds;
  bool get requiresVerification => _requiresVerification;
  bool get sessionReady => _sessionReady;
  SessionStatus get sessionStatus => _sessionStatus;

  User? _currentUser;
  User? get currentUser => _currentUser;

  /// True si hay un resetToken opaco pendiente en memoria (no persistido).
  bool get canCompletePasswordReset =>
      _passwordResetToken != null && _passwordResetToken!.isNotEmpty;

  /// Código funcional del último error en flujo de reset (p. ej. RESET_TOKEN_INVALID).
  String? get passwordResetErrorCode => _passwordResetErrorCode;
  String? _passwordResetErrorCode;

  void clearPasswordResetState() {
    _passwordResetToken = null;
    _passwordResetErrorCode = null;
  }

  @override
  Future<void> clearSessionState() async {
    _currentUser = null;
    _isLoading = false;
    _errorMessage = null;
    _requiresVerification = false;
    _sessionReady = true;
    clearPasswordResetState();
    // status lo fija quien invoca (expired vs guest)
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearVerificationFlag() {
    _requiresVerification = false;
    notifyListeners();
  }

  /// Email normalizado pendiente de OTP (persistido localmente).
  Future<String?> getPendingVerificationEmail() =>
      _pendingVerificationStore.read();

  Future<void> clearPendingVerificationEmail() =>
      _pendingVerificationStore.clear();

  /// Ruta inicial tras cold start sin sesión autenticada válida.
  Future<String> resolveColdStartRoute() async {
    final pending = await _pendingVerificationStore.read();
    if (pending != null && pending.isNotEmpty) {
      return '/verify-email';
    }
    return '/login';
  }

  Future<void> _savePendingVerificationEmail(String email) async {
    await _pendingVerificationStore.save(email);
  }

  String _toPublicError(Object e) => ErrorMapper.publicMessage(e);

  void _setSessionOwner(String? userId) {
    _sessionOwner?.setUserId(userId);
  }

  Future<void> _clearScopedSessionProviders() async {
    final resetter = _sessionStateResetter;
    if (resetter == null) return;
    await resetter.clearAll();
  }

  Future<User?> bootstrapSession() async {
    try {
      if (!_tokenStore.isInitialized) {
        await _tokenStore.initialize();
      }
      await _sessionMigrator.migrateIfNeeded();
    } on SecureStorageException {
      logDebug(
        '[AUTH] No se pudo inicializar el almacenamiento seguro / migración',
      );
      return _finishAsGuest();
    } catch (_) {
      logDebug('[AUTH] Error en bootstrap de sesión');
      return _finishAsGuest();
    }

    final profile = await _localRepository.getCurrentUser();
    final token = _tokenStore.isInitialized ? _tokenStore.getToken() : null;

    if (profile == null) {
      if (token != null && token.isNotEmpty) {
        try {
          await _tokenStore.clearToken();
        } catch (_) {
          logDebug('[AUTH] No se pudo limpiar token huérfano');
        }
      }
      return _finishAsGuest();
    }

    if (token == null || token.isEmpty || profile.role == 'guest') {
      if (profile.role == 'guest' && token != null && token.isNotEmpty) {
        try {
          await _tokenStore.clearToken();
        } catch (_) {
          logDebug('[AUTH] No se pudo limpiar token de perfil guest');
        }
      }
      return _finishAsGuest();
    }

    _currentUser = profile.copyWith(token: token);

    try {
      // 200: el perfil remoto es la fuente de verdad (rol, nombre, etc.).
      final fetchedUser = await _remoteDataSource.getMe();
      await _persistFetchedProfile(fetchedUser);
    } on AdminMobileNotSupportedException catch (e) {
      return _clearSessionForUnsupportedAdmin(e.message);
    } catch (_) {
      // Sin red u otro fallo: conservar sesión local restaurada.
    }

    final sessionUser = _currentUser;
    _sessionReady = true;
    _sessionStatus = SessionStatus.active;
    _setSessionOwner(sessionUser?.id ?? profile.id);
    _sessionExpirationHandler?.markActive();
    SessionFeedback.resetExpiredMessageGate();
    await _pendingVerificationStore.clear();
    notifyListeners();
    return sessionUser;
  }

  /// Persiste el perfil remoto en SQLite (sin JWT) y actualiza memoria.
  /// El token de sesión sigue viniendo de [TokenStore], igual que [syncProfile].
  Future<void> _persistFetchedProfile(User fetchedUser) async {
    await _localRepository.saveUser(fetchedUser.withoutToken());
    final sessionToken =
        _tokenStore.isInitialized ? _tokenStore.getToken() : null;
    _currentUser = fetchedUser.copyWith(
      token: sessionToken,
      clearToken: sessionToken == null,
    );
  }

  User? _finishAsGuest() {
    _currentUser = null;
    _sessionReady = true;
    _sessionStatus = SessionStatus.guest;
    _setSessionOwner(null);
    _sessionExpirationHandler?.markGuest();
    notifyListeners();
    return null;
  }

  /// Limpia sesión móvil cuando el backend reporta rol ADMIN.
  Future<User?> _clearSessionForUnsupportedAdmin(String message) async {
    logDebug('[AUTH] Rol ADMIN no soportado en móvil; limpiando sesión');
    _setSessionOwner(null);
    _currentUser = null;
    _requiresVerification = false;
    _sessionReady = true;
    _sessionStatus = SessionStatus.guest;
    _sessionExpirationHandler?.markGuest();
    _errorMessage = message;

    try {
      if (_tokenStore.isInitialized) {
        await _tokenStore.clearToken();
      }
    } catch (_) {
      logDebug('[AUTH] No se pudo limpiar token tras bloqueo ADMIN');
    }

    try {
      await _localRepository.logout();
    } catch (_) {
      logDebug('[AUTH] No se pudo limpiar perfil tras bloqueo ADMIN');
    }

    await _clearScopedSessionProviders();
    notifyListeners();
    return null;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _requiresVerification = false;
    notifyListeners();

    final normalizedEmail = Validators.normalizeEmail(email);
    try {
      final user = await _remoteDataSource.login(normalizedEmail, password);
      logDebug('[DEBUG AUTH_PROVIDER] Usuario autenticado id=${user.id}');
      await _persistAuthenticatedSession(user);
      _isLoading = false;
      notifyListeners();
      return true;
    } on EmailNotVerifiedException catch (e) {
      // Sin JWT ni sesión: el usuario debe completar OTP.
      await _savePendingVerificationEmail(normalizedEmail);
      _requiresVerification = true;
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      if (shouldPresentErrorToUser(e)) {
        _errorMessage = _toPublicError(e);
      } else {
        _errorMessage = null;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final idToken = await _googleAuthService.signIn();
      if (idToken == null) {
        // El usuario canceló
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Enviamos el token al backend para su validación
      final user = await _remoteDataSource.loginWithGoogle(idToken);
      logDebug('[DEBUG AUTH_PROVIDER] Usuario autenticado con Google id=${user.id}');
      await _persistAuthenticatedSession(user);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      logDebug('[DEBUG AUTH_PROVIDER] Error en loginWithGoogle: $e');
      _errorMessage = _toPublicError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String nombre,
    String apellido,
    String email,
    String password,
    String telefono, {
    int? rolId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _requiresVerification = false;
    notifyListeners();

    try {
      final normalizedEmail = Validators.normalizeEmail(email);
      final user = await _remoteDataSource.register(
        nombre,
        apellido,
        normalizedEmail,
        password,
        telefono,
        rolId: rolId,
      );
      logDebug('[DEBUG AUTH_PROVIDER] Usuario registrado id=${user.id}');

      // YA NO persistimos la sesión aquí porque el usuario aún no está verificado.
      // Solo indicamos que requiere verificación y recordamos el email para cold start.
      await _savePendingVerificationEmail(normalizedEmail);
      _requiresVerification = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _toPublicError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkEmailExists(String email) async {
    try {
      return await _remoteDataSource
          .checkEmailExists(Validators.normalizeEmail(email));
    } catch (_) {
      logDebug('[DEBUG AUTH_PROVIDER] Error checking email existence');
      return false;
    }
  }

  Future<bool> verifyEmail(String email, String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final normalizedEmail = Validators.normalizeEmail(email);
      final user = await _remoteDataSource.verifyEmail(
        normalizedEmail,
        code,
      );

      if (user != null) {
        _requiresVerification = false;
        logDebug('[DEBUG AUTH_PROVIDER] Correo verificado exitosamente');
        await _pendingVerificationStore.clear();
        await _persistAuthenticatedSession(user);
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Código inválido o expirado. Intenta de nuevo.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = _toPublicError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendCode(String email) async {
    _otpResendRetryAfterSeconds = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final normalizedEmail = Validators.normalizeEmail(email);
      await _savePendingVerificationEmail(normalizedEmail);
      final success = await _remoteDataSource
          .resendVerificationCode(normalizedEmail);
      _otpResendRetryAfterSeconds = null;
      notifyListeners();
      return success;
    } on OtpResendCooldownException catch (e) {
      _otpResendRetryAfterSeconds = e.retryAfterSeconds;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _otpResendRetryAfterSeconds = null;
      _errorMessage = _toPublicError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _passwordResetErrorCode = null;
    notifyListeners();

    try {
      await _remoteDataSource
          .requestPasswordReset(Validators.normalizeEmail(email));
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _toPublicError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPasswordResetCode(String email, String code) async {
    _isLoading = true;
    _errorMessage = null;
    _passwordResetErrorCode = null;
    notifyListeners();

    try {
      final token = await _remoteDataSource.verifyPasswordResetCode(
        Validators.normalizeEmail(email),
        code,
      );
      _passwordResetToken = token;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ResetCodeInvalidException {
      _errorMessage = ResetCodeInvalidException.defaultMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _toPublicError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completePasswordReset(String password) async {
    final token = _passwordResetToken;
    if (token == null || token.isEmpty) {
      _errorMessage = ResetTokenInvalidException.defaultMessage;
      _passwordResetErrorCode = ResetTokenInvalidException.errorCode;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _passwordResetErrorCode = null;
    notifyListeners();

    try {
      await _remoteDataSource.resetPassword(token, password);
      clearPasswordResetState();
      _isLoading = false;
      notifyListeners();
      return true;
    } on ResetTokenInvalidException catch (e) {
      clearPasswordResetState();
      _errorMessage = e.message;
      _passwordResetErrorCode = ResetTokenInvalidException.errorCode;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _toPublicError(e);
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
      logDebug('[DEBUG AUTH_PROVIDER] Usuario autenticado id=${user.id}');
      await _persistAuthenticatedSession(user);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (shouldPresentErrorToUser(e)) {
        _errorMessage = _toPublicError(e);
      } else {
        _errorMessage = null;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _persistAuthenticatedSession(User user) async {
    final jwt = user.token?.trim();
    if (jwt == null || jwt.isEmpty) {
      throw ValidationException(
          'La respuesta de autenticación no incluyó token');
    }

    // Limpia estado en memoria del usuario anterior antes de activar B.
    await _clearScopedSessionProviders();

    await _pendingVerificationStore.clear();
    await _tokenStore.saveToken(jwt);

    logDebug('[DEBUG AUTH_PROVIDER] Limpiando perfil local previo...');
    await _localRepository.logout();
    await _localRepository.saveUser(user.withoutToken());

    _currentUser = user.copyWith(token: jwt);
    _sessionReady = true;
    _sessionStatus = SessionStatus.active;
    _setSessionOwner(user.id);
    _sessionExpirationHandler?.markActive();
    SessionFeedback.resetExpiredMessageGate();
  }

  Future<void> syncProfile() async {
    try {
      logDebug('[DEBUG AUTH_PROVIDER] Starting syncProfile()');

      final fetchedUser = await _remoteDataSource.getMe();
      logDebug('[DEBUG AUTH_PROVIDER] Fetched user id=${fetchedUser.id}');

      await _persistFetchedProfile(fetchedUser);
      notifyListeners();

      logDebug('[DEBUG AUTH_PROVIDER] syncProfile completed successfully');
    } on AdminMobileNotSupportedException catch (e) {
      await _clearSessionForUnsupportedAdmin(e.message);
    } catch (_) {
      logDebug('[DEBUG AUTH_PROVIDER] Error syncing profile');
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

      logDebug(
        '[DEBUG AUTH_PROVIDER] Updating profile for user ${updatedUser.id}',
      );

      final resultUser = await _remoteDataSource.updateUser(updatedUser);
      await _localRepository.saveUser(resultUser.withoutToken());

      final token = _tokenStore.isInitialized ? _tokenStore.getToken() : null;
      _currentUser = resultUser.copyWith(
        token: token,
        clearToken: token == null,
      );

      logDebug('[DEBUG AUTH_PROVIDER] Profile updated successfully');
    } catch (e) {
      logDebug('[DEBUG AUTH_PROVIDER] Error updating profile');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Limpia perfil y estado local. Usado por [SessionExpirationHandler] ante 401.
  ///
  /// No navega. No borra pedidos offline SQLite. El token suele estar ya limpio.
  Future<void> clearLocalSessionForExpiration() async {
    logDebug('[AUTH] clearLocalSessionForExpiration()');
    _setSessionOwner(null);
    _currentUser = null;
    _requiresVerification = false;
    _sessionReady = true;
    _sessionStatus = SessionStatus.expired;
    _errorMessage = null;
    _isLoading = false;

    try {
      if (_tokenStore.isInitialized) {
        await _tokenStore.clearToken();
      }
    } catch (_) {
      logDebug('[AUTH] Falló clearToken en expiración');
    }

    try {
      await _localRepository.logout();
    } catch (_) {
      logDebug('[AUTH] Falló limpieza de perfil en expiración');
    }

    await _clearScopedSessionProviders();
    notifyListeners();
  }

  Future<void> logout() async {
    logDebug('[AUTH] logout() - Iniciando cierre de sesión');
    _setSessionOwner(null);
    _currentUser = null;
    _requiresVerification = false;
    _errorMessage = null;
    _isLoading = false;
    _sessionStatus = SessionStatus.guest;
    _sessionExpirationHandler?.markLoggedOut();
    clearPasswordResetState();

    try {
      await _googleAuthService.signOut();
    } catch (e) {
      logDebug('[AUTH] logout() - Google signOut falló (ignorado): $e');
    }

    Object? tokenError;
    Object? profileError;

    try {
      await _tokenStore.clearToken();
    } catch (e) {
      tokenError = e;
      logDebug('[AUTH] logout() - Falló limpieza de TokenStore');
    }

    try {
      await _localRepository.logout();
    } catch (e) {
      profileError = e;
      logDebug('[AUTH] logout() - Falló limpieza de perfil local');
    }

    await _clearScopedSessionProviders();
    notifyListeners();

    if (tokenError != null || profileError != null) {
      logDebug('[AUTH] logout() - Completado con errores parciales');
    } else {
      logDebug('[AUTH] logout() - Sesión cerrada');
    }
  }
}
