import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/user_repository.dart';

class ApiClient {
  final Dio _dio;
  final UserRepository _userRepository;

  ApiClient(this._userRepository)
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://clubs-api.onrender.com/api',
          connectTimeout: const Duration(seconds: 60), // Aumentado para Render cold start
          receiveTimeout: const Duration(seconds: 60), // Aumentado para respuestas lentas
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Ignorar token para endpoints públicos
        if (options.path.contains('/auth/login') || 
            options.path.contains('/auth/register') ||
            options.path.contains('/public/')) {
           return handler.next(options);
        }

        // Obtener token del usuario actual (asumiendo single user por ahora en local db)
        // Nota: En una app multi-usuario real, necesitaríamos saber cuál es el activo.
        // Aquí simplificamos buscando el usuario 'user_1' o el que esté marcado como activo.
        // Como getUser requiere ID, y no tenemos el ID en el interceptor,
        // quizás sea mejor que el Token se guarde en SecureStorage separado o UserProvider lo provea.
        // Por simplicidad y consistencia con lo hecho: buscaremos el usuario 'current' si existiera lógica,
        // o leeremos el token stored si lo separamos.
        // Dado el diseño actual en LocalUserRepository, vamos a intentar obtener el usuario principal.
        
        // Estrategia temporal: Leer de LocalUserRepository un usuario conocido o 'user_1'
        // Idealmente: SecureStorage.
        // Ajuste: Vamos a requerir que el token se pase o se obtenga de una fuente síncrona/rápida.
        // Por ahora, consultamos el repo.
        
        // Ajuste: Usamos el método getCurrentUser que acabamos de implementar
        final user = await _userRepository.getCurrentUser();
        if (user?.token != null) {
          options.headers['Authorization'] = 'Bearer ${user!.token}';
          if (kDebugMode) {
            print('[DEBUG API_CLIENT] Token encontrado para usuario ${user.id}');
            print('[DEBUG API_CLIENT] Token (primeros 20 chars): ${user.token!.substring(0, user.token!.length > 20 ? 20 : user.token!.length)}...');
          }
        } else {
          if (kDebugMode) {
            print('[DEBUG API_CLIENT] WARNING: No se encontró token para la petición a ${options.path}');
            print('[DEBUG API_CLIENT] Usuario actual: ${user?.id ?? "null"}');
          }
        }
        
        if (kDebugMode) {
            print('REQUEST[${options.method}] => PATH: ${options.path}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          print('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        if (kDebugMode) {
          print('ERROR[${e.response?.statusCode}] => PATH: ${e.requestOptions.path}');
          if (e.response?.statusCode == 401) {
            print('[DEBUG API_CLIENT] ERROR 401: Token expirado o inválido');
            print('[DEBUG API_CLIENT] Verificando token actual...');
            // El token podría estar expirado, pero no podemos hacer logout aquí
            // porque no tenemos acceso al contexto. El error se propagará y
            // la UI debería manejarlo.
          }
        }
        return handler.next(e);
      },
    ));
  }

  Dio get client => _dio;
}
