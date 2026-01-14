import 'package:dio/dio.dart';
import '../../../domain/entities/user.dart';

abstract class AuthRemoteDataSource {
  Future<User> login(String email, String password);
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

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['token'];
        
        // Manejo flexible de la respuesta (Plana vs Anidada)
        final Map<String, dynamic> userData;
        if (data.containsKey('usuario') && data['usuario'] != null) {
          userData = data['usuario'];
        } else {
          userData = data; // Estructura plana observada en pruebas
        }
        
        // Detección de Rol Real
        String role = 'member'; // Default: Socio/Invitado
        
        // Prioridad: rolId (según imágenes: 2=Admin, 3=Anfitrioni) o rolNombre
        final dynamic rolIdJson = userData['rolId']; 
        final int? rolId = rolIdJson is int ? rolIdJson : int.tryParse(rolIdJson?.toString() ?? '');
        final String? rolNombre = userData['rolNombre'] ?? userData['rol'];

        if (rolId != null) {
          // IDs: 2 (ADMIN), 3 (ANFITRION) -> Tratados como 'host' en la app por ahora
          if (rolId == 2 || rolId == 3) {
            role = 'host'; 
          }
        } else if (rolNombre != null) {
           final upperRol = rolNombre.toUpperCase();
           if (upperRol.contains('ADMIN') || upperRol == 'ANFITRION') {
             role = 'host';
           }
        }

        return User(
          id: (userData['userId'] ?? userData['id']).toString(), 
          name: "${userData['nombre']} ${userData['apellido']}",
          email: userData['email'],
          role: role, // Rol asignado real
          token: token,
          phone: userData['telefono'],
        );
      } else {
        throw Exception('Error en login: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }
}
