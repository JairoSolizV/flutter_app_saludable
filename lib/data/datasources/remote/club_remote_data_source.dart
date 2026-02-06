import 'package:dio/dio.dart';
import '../../../domain/entities/club_membership.dart';

class FotoClub {
  final int id;
  final int clubId;
  final String urlFoto;
  final String tipo;

  FotoClub({required this.id, required this.clubId, required this.urlFoto, required this.tipo});

  factory FotoClub.fromJson(Map<String, dynamic> json) {
    return FotoClub(
      id: json['id'],
      clubId: json['clubId'],
      urlFoto: json['urlFoto'],
      tipo: json['tipo'] ?? '',
    );
  }
}


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
  final String? fotoUrl;

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
    this.fotoUrl,
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
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      estado: json['estado'],
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

  // _fetchClubes y _getGuestToken eliminados ya que no son necesarios para la carga de clubes públicos

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

  Future<Club?> getClubById(int clubId) async {
    try {
      final clubes = await getClubes();
      try {
        return clubes.firstWhere((club) => club.id == clubId);
      } catch (e) {
        return null; // No encontrado
      }
    } catch (e) {
      print('Error buscando club por ID: $e');
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
    String? ciudad,
    String? descripcion,
    int hubId = 2,
  }) async {
    try {
      final body = {
        'anfitrionId': anfitrionId,
        'nombreClub': nombreClub,
        'direccion': direccion,
        'ciudad': ciudad ?? '',
        'descripcion': descripcion ?? '',
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

  Future<void> updateClub(int id, Map<String, dynamic> data) async {
    try {
      // Remove fotoUrl from data if present to avoid 500 error
      final cleanData = Map<String, dynamic>.from(data);
      cleanData.remove('fotoUrl');

      final response = await _client.put( // Changed to PUT based on standard, or verify if backend uses PUT/PATCH. Controller says @PutMapping("{id}")
        '/clubes/$id',
        data: cleanData,
      );

      if (response.statusCode != 200) {
        throw Exception('Error al actualizar club: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException) {
         throw Exception('Error actualizando club: ${e.message}');
      }
      throw Exception('Error al actualizar club: $e');
    }
  }

  Future<List<FotoClub>> getFotosClub(int clubId) async {
    try {
      final response = await _client.get('/fotos-club/club/$clubId');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => FotoClub.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching fotos: $e');
      return [];
    }
  }

  Future<void> subirFotoClub(int clubId, String urlFoto) async {
    try {
      // Endpoint: @PostMapping("/subir") params: clubId, urlFoto, tipo
      // It uses @RequestParam, so we pass query params or FormData? 
      // Controller: @PostMapping("/subir") @RequestParam ...
      // In Dio, for @RequestParam mixed with Post, we usually use queryParameters or FormData depending on Spring config. 
      // Safe bet for Spring @RequestParam in POST is usually query params OR x-www-form-urlencoded body.
      // Let's try queryParameters first as it's explicit for @RequestParam.
      
      final response = await _client.post(
        '/fotos-club/subir',
        queryParameters: {
          'clubId': clubId,
          'urlFoto': urlFoto,
          'tipo': 'PORTADA'
        }
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Error subiendo foto: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al subir foto: $e');
    }
  }

  Future<void> eliminarFoto(int id) async {
    await _client.delete('/fotos-club/$id');
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
