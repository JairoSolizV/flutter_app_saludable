import 'package:dio/dio.dart';
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
