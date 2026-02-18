import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/evento.dart';

abstract class EventoRemoteDataSource {
  Future<List<Evento>> getEventos();
  Future<List<Evento>> getEventosByHub(int hubId);
  Future<List<Evento>> getEventosByClub(int clubId);
}

class EventoRemoteDataSourceImpl implements EventoRemoteDataSource {
  final Dio _client;

  EventoRemoteDataSourceImpl(this._client);

  @override
  Future<List<Evento>> getEventos() async {
    try {
      debugPrint('[EVENTO DS] Obteniendo todos los eventos');
      debugPrint('[EVENTO DS] Endpoint: GET /api/eventos');
      
      final response = await _client.get('/eventos');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final eventos = data
            .map((json) => Evento.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        
        debugPrint('[EVENTO DS] Eventos obtenidos: ${eventos.length}');
        return eventos;
      } else {
        throw Exception('Error cargando eventos: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[EVENTO DS] Error al obtener eventos: $e');
      throw Exception('Error al obtener eventos: $e');
    }
  }

  @override
  Future<List<Evento>> getEventosByHub(int hubId) async {
    try {
      debugPrint('[EVENTO DS] Obteniendo eventos del hub: $hubId');
      
      final response = await _client.get(
        '/eventos',
        queryParameters: {'hubId': hubId},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => Evento.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      } else {
        throw Exception('Error cargando eventos del hub: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener eventos del hub: $e');
    }
  }

  @override
  Future<List<Evento>> getEventosByClub(int clubId) async {
    try {
      debugPrint('[EVENTO DS] Obteniendo eventos del club: $clubId');
      
      final response = await _client.get(
        '/eventos',
        queryParameters: {'clubId': clubId},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => Evento.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      } else {
        throw Exception('Error cargando eventos del club: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener eventos del club: $e');
    }
  }
}

