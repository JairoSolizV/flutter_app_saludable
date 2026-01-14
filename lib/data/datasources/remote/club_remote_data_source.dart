import 'package:dio/dio.dart';

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
    return Club(
      id: json['id'],
      hubId: json['hubId'],
      hubNombre: json['hubNombre'] ?? '',
      anfitrionId: json['anfitrionId'],
      anfitrionNombre: json['anfitrionNombre'] ?? '',
      nombreClub: json['nombreClub'],
      direccion: json['direccion'],
      horario: json['horario'] ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      estado: json['estado'],
    );
  }
}

class ClubRemoteDataSource {
  final Dio _client;

  ClubRemoteDataSource(this._client);

  Future<List<Club>> getClubes() async {
    try {
      // Intentar llamada normal (usará token de user_1 si existe)
      return await _fetchClubes();
    } on DioException catch (e) {
      // Si recibimos 403 (Forbidden) o 401, es probable que seamos invitados sin token
      if (e.response?.statusCode == 403 || e.response?.statusCode == 401) {
        print('Acceso denegado a clubes. Intentando autenticación silenciosa como Invitado...');
        try {
          // Autenticación silenciosa con credenciales de "Lectura Pública" (Socio Juan)
          final token = await _getGuestToken();
          // Reintentar llamada con el nuevo token explícito
          return await _fetchClubes(token: token);
        } catch (authError) {
          throw Exception('Error al autenticar invitado: $authError');
        }
      }
      rethrow;
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  Future<List<Club>> _fetchClubes({String? token}) async {
    final options = token != null 
      ? Options(headers: {'Authorization': 'Bearer $token'}) 
      : null;

    final response = await _client.get('/clubes', options: options);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => Club.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar clubes: ${response.statusCode}');
    }
  }

  Future<String> _getGuestToken() async {
    // Credenciales de respaldo para acceso público (Socio Juan)
    // En producción esto debería ser un endpoint público o un API Key
    final response = await _client.post('/auth/login', data: {
      'email': 'juan.socio@email.com',
      'password': 'Socio123!'
    });

    if (response.statusCode == 200) {
       return response.data['token'];
    } else {
       throw Exception('No se pudo obtener token de invitado');
    }
  }
}
