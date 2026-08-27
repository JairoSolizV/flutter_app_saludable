import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import 'package:flutter_app_saludable/core/utils/validators.dart';
import '../../../domain/entities/user.dart';

abstract class AuthRemoteDataSource {
  Future<User> login(String email, String password);
  Future<User> loginWithGoogle(String idToken);
  Future<User> register(String nombre, String apellido, String email,
      String password, String telefono,
      {int? rolId});
  Future<User> updateUser(User user);
  Future<User> getMe();
  Future<bool> checkEmailExists(String email);
  Future<User?> verifyEmail(String email, String code);
  Future<bool> resendVerificationCode(String email);
  Future<void> requestPasswordReset(String email);
  Future<String> verifyPasswordResetCode(String email, String code);
  Future<void> resetPassword(String resetToken, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _client;

  AuthRemoteDataSourceImpl(this._client);

  @visibleForTesting
  Dio get clientForTest => _client;

  @override
  Future<bool> checkEmailExists(String email) async {
    try {
      final normalized = Validators.normalizeEmail(email);
      final response = await _client.get(
        '/auth/check-email',
        queryParameters: {'email': normalized},
      );
      if (response.statusCode == 200) {
        return response.data['exists'] == true;
      }
      return false;
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e,
          fallback: 'Error al verificar disponibilidad del correo');
    }
  }

  @override
  Future<User> login(String email, String password) async {
    try {
      final response = await _client.post('/auth/login', data: {
        'email': Validators.normalizeEmail(email),
        'password': password,
      });
      return _parseAuthResponse(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e, fallback: 'Credenciales inválidas');
    }
  }

  @override
  Future<User> loginWithGoogle(String idToken) async {
    try {
      // Envía el idToken de Google al backend para validación y autenticación.
      // El backend valida el token con Google, busca/crea el usuario y devuelve JWT propio.
      final response = await _client.post('/auth/google', data: {
        'idToken': idToken,
      });
      return _parseAuthResponse(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e, fallback: 'Error al iniciar sesión con Google');
    }
  }

  @override
  Future<User> register(String nombre, String apellido, String email,
      String password, String telefono,
      {int? rolId}) async {
    try {
      final Map<String, dynamic> data = {
        'nombre': nombre,
        'apellido': apellido,
        'email': Validators.normalizeEmail(email),
        'password': password,
        'telefono': telefono,
      };

      if (rolId != null) {
        data['rolId'] = rolId;
      }

      final response = await _client.post('/auth/register', data: data);
      return _parseAuthResponse(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e, fallback: 'Error al registrar usuario');
    }
  }

  @override
  Future<User> updateUser(User user) async {
    try {
      Object? redesSocialesToSend = user.socialMedia;
      if (user.socialMedia != null && user.socialMedia!['instagram'] != null) {
        // Handle instagram string case
        redesSocialesToSend = user.socialMedia!['instagram'];
      }

      final Map<String, dynamic> data = {
        'nombre': user.name.split(' ').first,
        'apellido': user.name.split(' ').length > 1
            ? user.name.split(' ').sublist(1).join(' ')
            : '',
        'telefono': user.phone,
        'fechaNacimiento': user.birthDate,
        'redesSociales': redesSocialesToSend,
      };

      // Asumimos endpoint /auth/profile o /users/{id}
      // Según endpoints comunes, si no hay doc específica, usaremos /users/profile o update
      // Ajuste: El usuario mostró un JSON completo, lo más seguro es actualizar via PUT /users/{id} o similar.
      // Endpoint documentado: PUT /api/usuarios/perfil/{usuarioId}

      final response =
          await _client.put('/usuarios/perfil/${user.id}', data: data);

      // Si el backend devuelve el usuario actualizado
      if (response.statusCode == 200) {
        // Parsear respuesta si es necesario o devolver el usuario local actualizado si el backend solo confirma OK
        // Intentemos parsear por si acaso devuelve el obj
        return _parseAuthResponse(response);
      }
      return user;
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e, fallback: 'Error al actualizar perfil');
    }
  }

  @override
  Future<User> getMe() async {
    try {
      // Endpoint /api/auth/me verificado en SecurityConfig
      final response = await _client.get('/auth/me');
      return _parseAuthResponse(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e, fallback: 'Error al sincronizar perfil');
    }
  }

  User _parseAuthResponse(Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data;
      final token = data['token'];
      final tokenPresent =
          token is String ? token.isNotEmpty : token != null;

      // Asegurar que userData esté definido.
      // A veces viene en data['usuario'], a veces en data directamente.
      final userData = data['usuario'] ?? data;

      // Lógica robusta para Rol: nombre semántico (login/Google/OTP) o
      // objeto anidado en /me. El id de BD nunca decide el rol Flutter.
      String? rolNombreVal;

      if (userData.containsKey('rol')) {
        final rolData = userData['rol'];
        if (rolData is Map) {
          rolNombreVal = rolData['nombre']?.toString();
        } else if (rolData is String) {
          rolNombreVal = rolData;
        }
      } else {
        rolNombreVal = userData['rolNombre']?.toString();
      }

      // Sin JWT / secretos: solo metadatos seguros para depuración.
      logDebug('[DEBUG AUTH_REMOTE] Auth response:');
      logDebug('[DEBUG AUTH_REMOTE]   - Status: ${response.statusCode}');
      logDebug('[DEBUG AUTH_REMOTE]   - token presente: $tokenPresent');
      logDebug(
        '[DEBUG AUTH_REMOTE]   - userId: ${userData['userId'] ?? userData['id']}',
      );
      logDebug('[DEBUG AUTH_REMOTE]   - email: ${userData['email']}');
      logDebug('[DEBUG AUTH_REMOTE]   - rolNombre: $rolNombreVal');
      logDebug(
        '[DEBUG AUTH_REMOTE]   - requiresVerification: ${data['requiresVerification']}',
      );

      final role = mapBackendRoleToAppRole(rolNombreVal);

      final user = User(
        id: (userData['userId'] ?? userData['id']).toString(),
        name: "${userData['nombre']} ${userData['apellido']}",
        email: userData['email'],
        role: role,
        token: token,
        phone: userData['telefono'] ?? userData['phone'],
        birthDate: userData['fechaNacimiento'] ??
            userData['birthDate'] ??
            userData['birth_date'],
        socialMedia: _parseSocialMedia(userData['redesSociales'] ??
            userData['socialMedia'] ??
            userData['social_media']),
      );

      return user;
    } else {
      throw ServerException(
        'Error de autenticación',
        statusCode: response.statusCode,
      );
    }
  }

  /// Mapea el nombre de rol del backend al rol de la app.
  /// No usa ids de BD (1/2/3/4); solo nombres semánticos.
  @visibleForTesting
  static String mapBackendRoleToAppRole(String? rolNombre) {
    final normalized = rolNombre?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      throw ServerException(
        'Rol de usuario ausente en la respuesta del servidor',
        code: 'UNKNOWN_ROLE',
      );
    }

    switch (normalized) {
      case 'ADMIN':
        throw AdminMobileNotSupportedException();
      case 'ANFITRION':
        return 'host';
      case 'SOCIO':
        return 'member';
      case 'USUARIO_BASICO':
      case 'BASIC_USER':
        return 'basic_user';
      default:
        throw ServerException(
          'Rol de usuario no reconocido',
          code: 'UNKNOWN_ROLE',
        );
    }
  }

  Map<String, dynamic>? _parseSocialMedia(dynamic socialMediaData) {
    if (socialMediaData == null) return null;
    if (socialMediaData is Map) {
      return Map<String, dynamic>.from(socialMediaData);
    }
    if (socialMediaData is String) {
      // Si el backend devuelve un string (ej: "@usuario"), lo asumimos como instagram o generic
      return {'instagram': socialMediaData};
    }
    return null;
  }

  @override
  Future<User?> verifyEmail(String email, String code) async {
    try {
      final response = await _client.post('/auth/verify-email', data: {
        'email': Validators.normalizeEmail(email),
        'code': code,
      });
      if (response.statusCode == 200 && response.data['verified'] == true) {
        return _parseAuthResponse(response);
      }
      return null;
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e, fallback: 'Error al verificar el código');
    }
  }

  @override
  Future<bool> resendVerificationCode(String email) async {
    try {
      final response = await _client.post('/auth/resend-code', data: {
        'email': Validators.normalizeEmail(email),
      });
      if (response.statusCode == 200) {
        return response.data['success'] == true;
      }
      return false;
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e, fallback: 'Error al reenviar el código');
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      final response = await _client.post('/auth/forgot-password', data: {
        'email': Validators.normalizeEmail(email),
      });
      if (response.statusCode == 200 && response.data['success'] == true) {
        return;
      }
      throw ServerException(
        'No se pudo solicitar la recuperación de contraseña',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(
        e,
        fallback: 'No se pudo solicitar la recuperación de contraseña',
      );
    }
  }

  @override
  Future<String> verifyPasswordResetCode(String email, String code) async {
    try {
      final response = await _client.post('/auth/verify-reset-code', data: {
        'email': Validators.normalizeEmail(email),
        'code': code,
      });
      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['resetToken'];
        if (token is String && token.trim().isNotEmpty) {
          return token.trim();
        }
        throw ValidationException('Respuesta inválida del servidor');
      }
      throw ResetCodeInvalidException();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(
        e,
        fallback: ResetCodeInvalidException.defaultMessage,
      );
    }
  }

  @override
  Future<void> resetPassword(String resetToken, String password) async {
    try {
      final response = await _client.post('/auth/reset-password', data: {
        'resetToken': resetToken,
        'password': password,
      });
      if (response.statusCode == 200 && response.data['success'] == true) {
        return;
      }
      throw ResetTokenInvalidException();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(
        e,
        fallback: ResetTokenInvalidException.defaultMessage,
      );
    }
  }
}
