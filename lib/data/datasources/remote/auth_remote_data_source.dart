import 'package:dio/dio.dart';
import '../../../domain/entities/user.dart';

abstract class AuthRemoteDataSource {
  Future<User> login(String email, String password);
  Future<User> register(String nombre, String apellido, String email, String password, String telefono, {int? rolId});
  Future<User> updateUser(User user);
  Future<User> getMe();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _client;

  AuthRemoteDataSourceImpl(this._client);

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
  String _parseErrorMessage(DioException e, String defaultMessage) {
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;

    // Intentar extraer mensaje del backend
    if (responseData is Map && responseData.containsKey('message')) {
      return responseData['message'];
    }

    // Mensajes por código de estado
    switch (statusCode) {
      case 400:
        return 'Datos inv álidos. Por favor verifica tu información.';
      case 401:
        return 'Credenciales incorrectas. Verifica tu correo y contraseña.';
      case 403:
        return 'No tienes permisos para acceder.';
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
      final Map<String, dynamic> data = {
        'nombre': user.name.split(' ').first, // Aproximación
        'apellido': user.name.split(' ').length > 1 ? user.name.split(' ').sublist(1).join(' ') : '',
        'telefono': user.phone,
        'fechaNacimiento': user.birthDate,
        'redesSociales': user.socialMedia,
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
      // El token viene en login/register, pero NO en getMe (según evidencia)
      final token = data['token'];
      
      final Map<String, dynamic> userData;
      if (data.containsKey('usuario') && data['usuario'] != null) {
        userData = data['usuario'];
      } else {
        userData = data; 
      }
      
      String role = 'member';
      
      // Lógica robusta para Rol (puede venir como rolId, rolNombre, o objeto rol {id, nombre})
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
        if (rolId == 2 || rolId == 3) {
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

      return User(
        id: (userData['userId'] ?? userData['id']).toString(), 
        name: "${userData['nombre']} ${userData['apellido']}",
        email: userData['email'],
        role: role, 
        token: token, // Será null en getMe, AuthProvider debe manejar esto para no borrar el token local si ya existe
        phone: userData['telefono'],
        birthDate: userData['fechaNacimiento'],
        socialMedia: userData['redesSociales'] != null ? Map<String, dynamic>.from(userData['redesSociales']) : null,
      );
    } else {
      throw Exception('Error de autenticación: ${response.statusCode}');
    }
  }
}
