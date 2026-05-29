import 'package:dio/dio.dart';
import '../../../domain/entities/user.dart';

abstract class AuthRemoteDataSource {
  Future<User> login(String email, String password);
  Future<User> register(String nombre, String apellido, String email, String password, String telefono, {int? rolId});
  Future<User> updateUser(User user);
  Future<User> getMe();
  Future<bool> checkEmailExists(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _client;

  AuthRemoteDataSourceImpl(this._client);

  @override
  Future<bool> checkEmailExists(String email) async {
    try {
      final response = await _client.get('/auth/check-email', queryParameters: {'email': email});
      if (response.statusCode == 200) {
        return response.data['exists'] == true;
      }
      return false;
    } on DioException catch (e) {
      throw Exception(_parseErrorMessage(e, 'Error al verificar disponibilidad del correo'));
    }
  }

  @override
  Future<User> login(String email, String password) async {
    try {
      final response = await _client.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return _parseAuthResponse(response);
    } on DioException catch (e) {
      throw Exception(_parseErrorMessage(e, 'Credenciales inválidas'));
    }
  }

  /// Helper para parsear errores de forma amigable
  /// El backend devuelve ApiResponse con estructura: { success: false, message: "...", data: null }
  String _parseErrorMessage(DioException e, String defaultMessage) {
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;

    // El backend usa ApiResponse con estructura:
    // { success: false, message: "mensaje", data: null, timestamp: "..." }
    if (responseData is Map) {
      // Intentar extraer mensaje del ApiResponse del backend
      if (responseData.containsKey('message') && responseData['message'] != null) {
        final message = responseData['message'].toString();
        if (message.isNotEmpty) {
          return message;
        }
      }
      
      // Fallback: buscar en 'error' o 'errorMessage' (por si acaso)
      if (responseData.containsKey('error') && responseData['error'] != null) {
        return responseData['error'].toString();
      }
      if (responseData.containsKey('errorMessage') && responseData['errorMessage'] != null) {
        return responseData['errorMessage'].toString();
      }
    }

    // Mensajes por código de estado (fallback si no hay mensaje en la respuesta)
    switch (statusCode) {
      case 400:
        return 'Datos inválidos. Por favor verifica tu información.';
      case 401:
        // 401 puede ser: BadCredentialsException o AuthenticationException
        // El backend ya envía mensaje específico, pero si no llega, usamos este
        return 'Credenciales incorrectas. Verifica tu correo y contraseña.';
      case 403:
        // 403 es DisabledException - usuario deshabilitado
        return 'Usuario deshabilitado. Contacte al administrador.';
      case 404:
        return 'Usuario no encontrado.';
      case 500:
        return 'Error del servidor. Por favor intenta más tarde.';
      case 503:
        return 'Servicio no disponible. Intenta más tarde.';
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return 'Tiempo de espera agotado. Verifica tu conexión.';
        }
        if (e.type == DioExceptionType.connectionError) {
          return 'Error de conexión. Verifica tu internet.';
        }
        return defaultMessage;
    }
  }


  @override
  Future<User> register(String nombre, String apellido, String email, String password, String telefono, {int? rolId}) async {
    try {
      final Map<String, dynamic> data = {
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'password': password,
        'telefono': telefono,
      };
      
      if (rolId != null) {
        data['rolId'] = rolId;
      }

      final response = await _client.post('/auth/register', data: data);
      return _parseAuthResponse(response);
    } on DioException catch (e) {
      throw Exception(_parseErrorMessage(e, 'Error al registrar usuario'));
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
        'apellido': user.name.split(' ').length > 1 ? user.name.split(' ').sublist(1).join(' ') : '',
        'telefono': user.phone,
        'fechaNacimiento': user.birthDate,
        'redesSociales': redesSocialesToSend,
      };

      // Asumimos endpoint /auth/profile o /users/{id}
      // Según endpoints comunes, si no hay doc específica, usaremos /users/profile o update
      // Ajuste: El usuario mostró un JSON completo, lo más seguro es actualizar via PUT /users/{id} o similar.
      // Endpoint documentado: PUT /api/usuarios/perfil/{usuarioId}
      
      final response = await _client.put('/usuarios/perfil/${user.id}', data: data);
      
      // Si el backend devuelve el usuario actualizado
      if(response.statusCode == 200) {
        // Parsear respuesta si es necesario o devolver el usuario local actualizado si el backend solo confirma OK
        // Intentemos parsear por si acaso devuelve el obj
        return _parseAuthResponse(response); 
      }
      return user;

    } on DioException catch (e) {
       throw Exception(_parseErrorMessage(e, 'Error al actualizar perfil'));
    }
  }

  @override
  Future<User> getMe() async {
    try {
      // Endpoint /api/auth/me verificado en SecurityConfig
      final response = await _client.get('/auth/me');
      return _parseAuthResponse(response);
    } on DioException catch (e) {
      throw Exception(_parseErrorMessage(e, 'Error al sincronizar perfil'));
    }
  }

  User _parseAuthResponse(Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data;
      final token = data['token'];
      
      print('[DEBUG AUTH_REMOTE] Parsing auth response:');
      print('[DEBUG AUTH_REMOTE]   - Status: ${response.statusCode}');
      print('[DEBUG AUTH_REMOTE]   - Token presente: ${token != null}');
      if (token != null) {
        print('[DEBUG AUTH_REMOTE]   - Token length: ${token.length}');
        if (token.length > 20) {
          print('[DEBUG AUTH_REMOTE]   - Token preview: ${token.substring(0, 20)}...');
        }
      }
      
      // Asegurar que userData esté definido. 
      // A veces viene en data['usuario'], a veces en data directamente.
      final userData = data['usuario'] ?? data;

      // DEBUG: Print raw userData
      print('[DEBUG AUTH_REMOTE] Raw userData from backend: $userData');
      
      String role = 'member';
      
      // Lógica robusta para Rol
      dynamic rolIdVal;
      String? rolNombreVal;

      if (userData.containsKey('rol')) {
         final rolData = userData['rol'];
         if (rolData is Map) {
            rolIdVal = rolData['id'];
            rolNombreVal = rolData['nombre'];
         } else if (rolData is int) {
            rolIdVal = rolData; 
         } else if (rolData is String) {
            rolNombreVal = rolData;
         }
      } else {
         rolIdVal = userData['rolId'];
         rolNombreVal = userData['rolNombre'];
      }

      final int? rolId = rolIdVal is int ? rolIdVal : int.tryParse(rolIdVal?.toString() ?? '');
      
      if (rolId != null) {
        if (rolId == 1 || rolId == 3) { 
          role = 'host'; 
        } else if (rolId == 4) {
          role = 'basic_user';
        }
      } else if (rolNombreVal != null) {
         final upperRol = rolNombreVal.toUpperCase();
         if (upperRol.contains('ADMIN') || upperRol == 'ANFITRION') {
           role = 'host';
         } else if (upperRol == 'USUARIO_BASICO' || upperRol == 'BASIC_USER') {
           role = 'basic_user';
         }
      }

      final user = User(
        id: (userData['userId'] ?? userData['id']).toString(), 
        name: "${userData['nombre']} ${userData['apellido']}",
        email: userData['email'],
        role: role, 
        token: token, 
        phone: userData['telefono'] ?? userData['phone'],
        birthDate: userData['fechaNacimiento'] ?? userData['birthDate'] ?? userData['birth_date'],
        socialMedia: _parseSocialMedia(userData['redesSociales'] ?? userData['socialMedia'] ?? userData['social_media']),
      );
      
      return user;
    } else {
      throw Exception('Error de autenticación: ${response.statusCode}');
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
}
