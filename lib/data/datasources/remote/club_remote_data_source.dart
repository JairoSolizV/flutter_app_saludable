import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/clubs/club_location.dart';
import 'package:flutter_app_saludable/core/clubs/club_prefix.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/throw_app_error.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import '../../../core/pagination/paged_result.dart';
import '../../../domain/entities/club_membership.dart';

class FotoClub {
  final int id;
  final int clubId;
  final String urlFoto;
  final String tipo;

  FotoClub(
      {required this.id,
      required this.clubId,
      required this.urlFoto,
      required this.tipo});

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
  final double? lat;
  final double? lng;
  final String? prefijoSocio;
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
    this.lat,
    this.lng,
    this.prefijoSocio,
    required this.estado,
  });

  bool get hasValidLocation =>
      ClubLocationValidation.isValidCoordinates(lat, lng);

  bool get hasValidPrefix => ClubPrefixValidation.isValid(prefijoSocio);

  factory Club.fromJson(Map<String, dynamic> json) {
    double? parseCoordinate(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
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
      lat: parseCoordinate(json['lat']),
      lng: parseCoordinate(json['lng']),
      prefijoSocio: json['prefijoSocio']?.toString(),
      estado: json['estado']?.toString() ?? 'ACTIVO',
    );
  }
}

class ClubRemoteDataSource {
  final Dio _client;

  ClubRemoteDataSource(this._client);

  /// Obtiene todos los clubes activos
  /// Endpoint: GET /api/public/clubes
  /// Este endpoint devuelve solo clubes con estado ACTIVO o APROBADO
  /// No requiere validación por HUB o membresía - cualquier socio puede ver todos los clubes activos
  Future<List<Club>> getClubes() async {
    try {
      debugPrint(
          '[DEBUG CLUB] Obteniendo clubes activos desde endpoint público');
      debugPrint('[DEBUG CLUB] Endpoint: GET /api/public/clubes');

      final response = await _client.get('/public/clubes');

      debugPrint(
          '[DEBUG CLUB] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint(
          '[DEBUG CLUB] Response body type: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        final dynamic data = response.data;
        List<dynamic> clubesList = [];

        if (data is List) {
          clubesList = data;
        } else if (data is Map) {
          if (data.containsKey('content') && data['content'] is List) {
            clubesList = data['content'] as List<dynamic>;
          } else if (data.containsKey('data') && data['data'] is List) {
            clubesList = data['data'] as List<dynamic>;
          }
        }

        final clubes = clubesList.map((json) => Club.fromJson(json)).toList();
        debugPrint('[DEBUG CLUB] Clubes activos encontrados: ${clubes.length}');

        // Log de los primeros 3 clubes para debug
        if (clubes.isNotEmpty) {
          debugPrint('[DEBUG CLUB] Primeros clubes:');
          clubes.take(3).forEach((club) {
            debugPrint(
                '[DEBUG CLUB]   - ${club.nombreClub} (ID: ${club.id}, Estado: ${club.estado}, HUB: ${club.hubId})');
          });
        }

        return clubes;
      } else {
        throw ServerException('Error al cargar clubes',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error obteniendo clubes activos', stackTrace: st);
    } catch (e, st) {
      rethrowApp(e, fallback: 'Error obteniendo clubes', stackTrace: st);
    }
  }

  /// Obtiene los clubes de un HUB específico
  /// Endpoint: GET /api/clubes?hubId={hubId}
  Future<List<Club>> getClubesByHub(int hubId) async {
    try {
      debugPrint('[DEBUG CLUB] Obteniendo clubes del HUB - hubId: $hubId');
      debugPrint('[DEBUG CLUB] Endpoint: GET /api/clubes?hubId=$hubId');

      final response =
          await _client.get('/clubes', queryParameters: {'hubId': hubId});

      debugPrint(
          '[DEBUG CLUB] Respuesta recibida - Status: ${response.statusCode}');
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
        throw ServerException('Error al cargar clubes del HUB',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error obteniendo clubes del HUB', stackTrace: st);
    } catch (e, st) {
      rethrowApp(e,
          fallback: 'Error obteniendo clubes del HUB', stackTrace: st);
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

      debugPrint(
          '[DEBUG CLUB] Respuesta recibida - Status: ${response.statusCode}');
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
        throw UnauthorizedException(
            'No autenticado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        debugPrint('[DEBUG CLUB] ERROR 403: Sin permisos');
        throw ForbiddenException(
            'No tienes permisos para acceder a esta información.');
      } else if (response.statusCode == 500) {
        debugPrint('[DEBUG CLUB] ERROR 500: Error del servidor');
        throw ServerException(
            'Error del servidor. Por favor intenta más tarde.',
            statusCode: 500);
      } else {
        debugPrint('[DEBUG CLUB] ERROR: Status code ${response.statusCode}');
        throw ServerException('Error al obtener club',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e,
          fallback: 'Error del servidor. Por favor intenta más tarde.',
          stackTrace: st);
    } catch (e, st) {
      debugPrint('[DEBUG CLUB] Error general: $e');
      // Si el error contiene "No se encontró", es un error del backend
      if (e.toString().contains('No se encontró')) {
        rethrow;
      }
      rethrowApp(e,
          fallback: 'Error buscando club del anfitrión', stackTrace: st);
    }
  }

  /// Método legacy - mantener por compatibilidad pero usar getMyClub() en su lugar
  @Deprecated(
      'Usar getMyClub() en su lugar. Este método obtiene todos los clubes y filtra.')
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
      logDebug('Error buscando club del anfitrión: $e');
      return null;
    }
  }

  /// Obtiene un club por su ID usando GET /api/clubes/{id}
  Future<Club?> getClubById(int clubId) async {
    try {
      debugPrint('[DEBUG CLUB] Obteniendo club por ID - clubId: $clubId');
      debugPrint('[DEBUG CLUB] Endpoint: GET /api/clubes/$clubId');

      final response = await _client.get('/clubes/$clubId');

      debugPrint(
          '[DEBUG CLUB] Respuesta recibida - Status: ${response.statusCode}');
      debugPrint('[DEBUG CLUB] Response body: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final club = Club.fromJson(data);
          debugPrint(
              '[DEBUG CLUB] Club encontrado - ID: ${club.id}, Nombre: ${club.nombreClub}');
          return club;
        } else {
          debugPrint('[DEBUG CLUB] WARNING: Formato de respuesta inesperado');
          return null;
        }
      } else if (response.statusCode == 404) {
        debugPrint('[DEBUG CLUB] Club no encontrado (404)');
        return null;
      } else {
        throw ServerException('Error al obtener club',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      final statusCode = e.response?.statusCode;
      debugPrint('[DEBUG CLUB] DioException - Status: $statusCode');
      debugPrint('[DEBUG CLUB] Error: ${e.message}');

      if (statusCode == 404) {
        return null; // Club no encontrado, no es un error crítico
      }
      throwDioAsApp(e, fallback: 'Error obteniendo club', stackTrace: st);
    } catch (e) {
      debugPrint('[DEBUG CLUB] Error general obteniendo club por ID: $e');
      return null;
    }
  }

  Future<Anfitrion> getAnfitrion(int id) async {
    try {
      return await _fetchAnfitrion(id);
    } catch (e) {
      logDebug('Error fetching anfitrion: $e');
      return Anfitrion(
          id: id,
          nombre: '',
          apellido: '',
          email: '',
          telefono: '',
          redesSociales: '');
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
        throw ServerException('Error al cargar socios',
            statusCode: response.statusCode);
      }
    } catch (e, st) {
      rethrowApp(e,
          fallback: 'Error detallado al obtener socios', stackTrace: st);
    }
  }

  /// Versión paginada de [getClubMembers].
  /// Endpoint: GET /membresias/club/{clubId}/paginadas?page&size&q
  Future<PagedResult<ClubMembership>> getClubMembersPage(
    int clubId, {
    int page = 0,
    int size = 20,
    String? q,
  }) async {
    try {
      final response = await _client.get(
        '/membresias/club/$clubId/paginadas',
        queryParameters: {
          'page': page,
          'size': size,
          if (q != null && q.isNotEmpty) 'q': q,
        },
      );

      final dynamic data = response.data;
      if (data is! Map) {
        throw ServerException('Respuesta inesperada al obtener socios');
      }
      return PagedResult<ClubMembership>.fromJson(
        Map<String, dynamic>.from(data),
        (json) => ClubMembership.fromJson(json),
      );
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error al cargar socios', stackTrace: st);
    } catch (e, st) {
      rethrowApp(e,
          fallback: 'Error al obtener socios paginados', stackTrace: st);
    }
  }

  Future<void> solicitarCreacionClub({
    required int anfitrionId,
    required String nombreClub,
    required String direccion,
    String? ciudad,
    String? descripcion,
    required String horario,
    required double lat,
    required double lng,
    required String prefijoSocio,
    int hubId = 1,
  }) async {
    try {
      if (!ClubLocationValidation.isValidCoordinates(lat, lng)) {
        throw Exception('Las coordenadas de ubicación no son válidas');
      }
      if (!ClubPrefixValidation.isValid(prefijoSocio)) {
        throw Exception(ClubPrefixFormMessages.invalid);
      }

      final normalizedPrefix = ClubPrefixValidation.normalize(prefijoSocio);

      debugPrint('[CLUB DS] Solicitud de creación de club:');
      debugPrint('[CLUB DS]   nombreClub: $nombreClub');
      debugPrint('[CLUB DS]   direccion: $direccion');
      debugPrint('[CLUB DS]   horario: $horario');
      debugPrint('[CLUB DS]   lat: $lat (tipo: ${lat.runtimeType})');
      debugPrint('[CLUB DS]   lng: $lng (tipo: ${lng.runtimeType})');
      debugPrint('[CLUB DS]   prefijoSocio: $normalizedPrefix');
      debugPrint('[CLUB DS]   hubId: $hubId');
      debugPrint('[CLUB DS]   anfitrionId: $anfitrionId');

      final body = {
        'nombreClub': nombreClub,
        'direccion': direccion,
        'horario': horario,
        'lat': lat,
        'lng': lng,
        'prefijoSocio': normalizedPrefix,
        'estado': 'PENDIENTE',
      };

      debugPrint('[CLUB DS] Body a enviar: $body');

      final response = await _client.post(
        '/clubes',
        data: body,
        queryParameters: {
          'hubId': hubId,
          'anfitrionId': anfitrionId,
        },
      );

      debugPrint('[CLUB DS] Respuesta del servidor: ${response.statusCode}');
      debugPrint('[CLUB DS] Response data: ${response.data}');

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw ServerException('Error al solicitar club',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error solicitud club', stackTrace: st);
    } catch (e, st) {
      rethrowApp(e, fallback: 'Error al solicitar club', stackTrace: st);
    }
  }

  Future<void> updateClub(int id, Map<String, dynamic> data) async {
    try {
      // Remove fotoUrl from data if present to avoid 500 error
      final cleanData = Map<String, dynamic>.from(data);
      cleanData.remove('fotoUrl');

      // Using PUT as per backend standard for full/partial updates often in Spring if @PutMapping is used
      final response = await _client.put(
        '/clubes/$id',
        data: cleanData,
      );

      if (response.statusCode != 200) {
        throw ServerException('Error al actualizar club',
            statusCode: response.statusCode);
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error actualizando club', stackTrace: st);
    } catch (e, st) {
      rethrowApp(e, fallback: 'Error al actualizar club', stackTrace: st);
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
      logDebug('Error fetching fotos: $e');
      return [];
    }
  }

  Future<void> subirFotoClub(int clubId, String urlFoto) async {
    try {
      final response = await _client.post('/fotos-club/subir',
          queryParameters: {
            'clubId': clubId,
            'urlFoto': urlFoto,
            'tipo': 'PORTADA'
          });

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw ServerException('Error subiendo foto',
            statusCode: response.statusCode);
      }
    } catch (e, st) {
      rethrowApp(e, fallback: 'Error al subir foto', stackTrace: st);
    }
  }

  Future<void> eliminarFoto(int id) async {
    await _client.delete('/fotos-club/$id');
  }

  Future<List<ClubMembership>> getReferidosPorMembresia(int membresiaId) async {
    try {
      final response = await _client.get('/membresias/$membresiaId/referidos');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((e) => ClubMembership.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404) return [];
      throwDioAsApp(e, fallback: 'Error obteniendo referidos', stackTrace: st);
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
