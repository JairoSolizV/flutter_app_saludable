import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/club_membership.dart';


class Club {
  final int id;
  final int hubId;
  final String hubNombre;
  final int anfitrionId;
  final String anfitrionNombre;
  final String nombreClub;
  final String direccion;
  final String horario;
  final double lat;
  final double lng;
  final String estado;

  Club({
    required this.id,
    required this.hubId,
    required this.hubNombre,
    required this.anfitrionId,
    required this.anfitrionNombre,
    required this.nombreClub,
    required this.direccion,
    required this.horario,
    required this.lat,
    required this.lng,
    required this.estado,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    // Manejar lat y lng de forma segura (pueden ser null)
    double parseLat() {
      final latValue = json['lat'];
      if (latValue == null) return 0.0;
      if (latValue is num) return latValue.toDouble();
      if (latValue is String) return double.tryParse(latValue) ?? 0.0;
      return 0.0;
    }
    
    double parseLng() {
      final lngValue = json['lng'];
      if (lngValue == null) return 0.0;
      if (lngValue is num) return lngValue.toDouble();
      if (lngValue is String) return double.tryParse(lngValue) ?? 0.0;
      return 0.0;
    }
    
    return Club(
      id: json['id'] as int,
      hubId: json['hubId'] as int,
      hubNombre: json['hubNombre']?.toString() ?? '',
      anfitrionId: json['anfitrionId'] as int,
      anfitrionNombre: json['anfitrionNombre']?.toString() ?? '',
      nombreClub: json['nombreClub']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      horario: json['horario']?.toString() ?? '',
      lat: parseLat(),
      lng: parseLng(),
      estado: json['estado']?.toString() ?? 'ACTIVO',
    );
  }
}

class ClubRemoteDataSource {
  final Dio _client;

  ClubRemoteDataSource(this._client);

  Future<List<Club>> getClubes() async {
    try {
      // Uso del nuevo endpoint público
      // Como la BaseUrl ya incluye /api (asumido por el uso de /clubes), usamos /public/clubes
      // Si falla, verificar si la baseUrl del Dio incluye /api
      final response = await _client.get('/public/clubes');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Club.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar clubes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error obteniendo clubes públicos: $e');
    }
  }

  /// Obtiene los clubes de un HUB específico
  /// Endpoint: GET /api/clubes?hubId={hubId}
  Future<List<Club>> getClubesByHub(int hubId) async {
    try {
      debugPrint('[DEBUG CLUB] Obteniendo clubes del HUB - hubId: $hubId');
      debugPrint('[DEBUG CLUB] Endpoint: GET /api/clubes?hubId=$hubId');
      
      final response = await _client.get(
        '/clubes',
        queryParameters: {'hubId': hubId}
      );
      
      debugPrint('[DEBUG CLUB] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG CLUB] Response body: ${response.data}');
      
      if (response.statusCode == 200) {
        final dynamic data = response.data;
        List<dynamic> clubesList = [];
        
        if (data is List) {
          clubesList = data;
        } else if (data is Map) {
          if (data.containsKey('content')) {
            clubesList = data['content'] as List<dynamic>;
          } else if (data.containsKey('data')) {
            clubesList = data['data'] as List<dynamic>;
          }
        }
        
        final clubes = clubesList.map((json) => Club.fromJson(json)).toList();
        debugPrint('[DEBUG CLUB] Clubes encontrados: ${clubes.length}');
        return clubes;
      } else {
        throw Exception('Error al cargar clubes del HUB: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      debugPrint('[DEBUG CLUB] DioException - Status: $statusCode');
      debugPrint('[DEBUG CLUB] Error: ${e.message}');
      
      if (statusCode == 401) {
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (statusCode == 403) {
        throw Exception('No tienes permisos para ver los clubes.');
      } else if (statusCode == 500) {
        throw Exception('Error del servidor. Por favor intenta más tarde.');
      }
      
      final errorMessage = e.response?.data?['message'] ?? e.message ?? 'Error desconocido';
      throw Exception('Error obteniendo clubes del HUB: $errorMessage');
    } catch (e) {
      debugPrint('[DEBUG CLUB] Error general obteniendo clubes del HUB: $e');
      throw Exception('Error obteniendo clubes del HUB: $e');
    }
  }

  // _fetchClubes y _getGuestToken eliminados ya que no son necesarios para la carga de clubes públicos

  /// Obtiene el club del anfitrión autenticado usando GET /api/clubes/mio
  /// Este es el método CORRECTO según el backend confirmado
  Future<Club?> getMyClub() async {
    try {
      debugPrint('[DEBUG CLUB] Obteniendo club del anfitrión autenticado');
      debugPrint('[DEBUG CLUB] Endpoint: GET /api/clubes/mio');
      
      final response = await _client.get('/clubes/mio');
      
      debugPrint('[DEBUG CLUB] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG CLUB] Response body: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final club = Club.fromJson(data);
          debugPrint('[DEBUG CLUB] ClubId anfitrión: ${club.id}');
          debugPrint('[DEBUG CLUB] Nombre del club: ${club.nombreClub}');
          return club;
        } else if (data is List && data.isNotEmpty) {
          // Si devuelve una lista, tomar el primero
          final club = Club.fromJson(data.first);
          debugPrint('[DEBUG CLUB] ClubId anfitrión: ${club.id}');
          return club;
        } else {
          debugPrint('[DEBUG CLUB] WARNING: Formato de respuesta inesperado');
          return null;
        }
      } else if (response.statusCode == 401) {
        debugPrint('[DEBUG CLUB] ERROR 401: No autenticado');
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        debugPrint('[DEBUG CLUB] ERROR 403: Sin permisos');
        throw Exception('No tienes permisos para acceder a esta información.');
      } else if (response.statusCode == 500) {
        debugPrint('[DEBUG CLUB] ERROR 500: Error del servidor');
        throw Exception('Error del servidor. Por favor intenta más tarde.');
      } else {
        debugPrint('[DEBUG CLUB] ERROR: Status code ${response.statusCode}');
        throw Exception('Error al obtener club: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      debugPrint('[DEBUG CLUB] DioException - Status: $statusCode');
      debugPrint('[DEBUG CLUB] Error: ${e.message}');
      debugPrint('[DEBUG CLUB] Response data: ${e.response?.data}');
      
      if (statusCode == 401) {
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (statusCode == 403) {
        throw Exception('No tienes permisos para acceder a esta información.');
      } else if (statusCode == 404) {
        // El backend devuelve 404 cuando no se encuentra el club del anfitrión
        final errorMessage = e.response?.data?['message']?.toString() ?? 
                           'No se encontró ningún club asignado a tu cuenta. Verifica que tengas un club asignado como anfitrión.';
        debugPrint('[DEBUG CLUB] ERROR 404: $errorMessage');
        throw Exception(errorMessage);
      } else if (statusCode == 500) {
        throw Exception('Error del servidor. Por favor intenta más tarde.');
      } else {
        final errorMessage = e.response?.data?['message']?.toString() ?? 
                           e.message ?? 
                           'Error desconocido al obtener club';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[DEBUG CLUB] Error general: $e');
      // Si el error contiene "No se encontró", es un error del backend
      if (e.toString().contains('No se encontró')) {
        rethrow;
      }
      throw Exception('Error buscando club del anfitrión: $e');
    }
  }

  /// Método legacy - mantener por compatibilidad pero usar getMyClub() en su lugar
  @Deprecated('Usar getMyClub() en su lugar. Este método obtiene todos los clubes y filtra.')
  Future<Club?> getClubByHostId(int hostId) async {
    try {
      // Como no hay endpoint específico, obtenemos todos y filtramos
      // Esto es temporal hasta tener un endpoint optimizado
      final clubes = await getClubes();
      try {
        return clubes.firstWhere((club) => club.anfitrionId == hostId);
      } catch (e) {
        return null; // No encontrado
      }
    } catch (e) {
      print('Error buscando club del anfitrión: $e');
      return null;
    }
  }

  /// Obtiene un club por su ID usando GET /api/clubes/{id}
  Future<Club?> getClubById(int clubId) async {
    try {
      debugPrint('[DEBUG CLUB] Obteniendo club por ID - clubId: $clubId');
      debugPrint('[DEBUG CLUB] Endpoint: GET /api/clubes/$clubId');
      
      final response = await _client.get('/clubes/$clubId');
      
      debugPrint('[DEBUG CLUB] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG CLUB] Response body: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final club = Club.fromJson(data);
          debugPrint('[DEBUG CLUB] Club encontrado - ID: ${club.id}, Nombre: ${club.nombreClub}');
          return club;
        } else {
          debugPrint('[DEBUG CLUB] WARNING: Formato de respuesta inesperado');
          return null;
        }
      } else if (response.statusCode == 404) {
        debugPrint('[DEBUG CLUB] Club no encontrado (404)');
        return null;
      } else {
        throw Exception('Error al obtener club: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      debugPrint('[DEBUG CLUB] DioException - Status: $statusCode');
      debugPrint('[DEBUG CLUB] Error: ${e.message}');
      
      if (statusCode == 404) {
        return null; // Club no encontrado, no es un error crítico
      } else if (statusCode == 401) {
        throw Exception('No autenticado. Por favor inicia sesión nuevamente.');
      } else if (statusCode == 403) {
        throw Exception('No tienes permisos para ver este club.');
      } else if (statusCode == 500) {
        throw Exception('Error del servidor. Por favor intenta más tarde.');
      }
      
      final errorMessage = e.response?.data?['message'] ?? e.message ?? 'Error desconocido';
      throw Exception('Error obteniendo club: $errorMessage');
    } catch (e) {
      debugPrint('[DEBUG CLUB] Error general obteniendo club por ID: $e');
      return null;
    }
  }

  Future<Anfitrion> getAnfitrion(int id) async {
    try {
      return await _fetchAnfitrion(id);
    } catch (e) {
      print('Error fetching anfitrion: $e');
      return Anfitrion(id: id, nombre: '', apellido: '', email: '', telefono: '', redesSociales: '');
    }
  }

  Future<Anfitrion> _fetchAnfitrion(int id, {String? token}) async {
    final options = token != null 
       ? Options(headers: {'Authorization': 'Bearer $token'}) 
       : null;
    final response = await _client.get('/usuarios/$id', options: options);
    if (response.statusCode == 200) {
      return Anfitrion.fromJson(response.data);
    } else {
      throw Exception('Failed to load anfitrion');
    }
  }
  Future<List<ClubMembership>> getClubMembers(int clubId) async {
    try {
      final response = await _client.get('/membresias/club/$clubId');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ClubMembership.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar socios: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error detallado al obtener socios: $e');
    }
  }

  Future<void> solicitarCreacionClub({
    required int anfitrionId,
    required String nombreClub,
    required String direccion,
    int hubId = 2,
  }) async {
    try {
      final body = {
        'anfitrionId': anfitrionId,
        'nombreClub': nombreClub,
        'direccion': direccion,
        'hubId': hubId,
        'estado': 'PENDIENTE', 
      };

      final response = await _client.post(
        '/clubes', 
        data: body,
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Error al solicitar club: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException) {
         final msg = e.response?.data?.toString() ?? e.message;
         throw Exception('Error solicitud club: $msg');
      }
      throw Exception('Error al solicitar club: $e');
    }
  }
}

class Anfitrion {
  final int id;
  final String nombre;
  final String apellido;
  final String email;
  final String telefono;
  final String redesSociales;

  Anfitrion({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.telefono,
    required this.redesSociales,
  });

  factory Anfitrion.fromJson(Map<String, dynamic> json) {
    return Anfitrion(
      id: json['id'] ?? json['userId'] ?? 0,
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      email: json['email'] ?? '',
      telefono: json['telefono'] ?? '',
      redesSociales: json['redesSociales'] ?? '',
    );
  }
}
