import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_saludable/core/errors/throw_app_error.dart';
import '../../../domain/entities/support_ticket.dart';

abstract class SupportRemoteDataSource {
  Future<void> createTicket({
    required String tipoSolicitud,
    required String asunto,
    required String mensaje,
  });
  Future<List<SupportTicket>> getMyTickets();
}

class SupportRemoteDataSourceImpl implements SupportRemoteDataSource {
  final Dio _client;

  SupportRemoteDataSourceImpl(this._client);

  @override
  Future<void> createTicket({
    required String tipoSolicitud,
    required String asunto,
    required String mensaje,
  }) async {
    try {
      debugPrint('[DEBUG SOPORTE] Creando ticket: $asunto ($tipoSolicitud)');

      final response = await _client.post(
        '/soporte-tickets',
        data: {
          'tipoSolicitud': tipoSolicitud,
          'asunto': asunto,
          'mensaje': mensaje,
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error al crear ticket');
      }
      debugPrint('[DEBUG SOPORTE] Ticket creado con éxito');
    } on DioException catch (e, st) {
      throwDioAsApp(
        e,
        fallback: 'Error al crear ticket de soporte',
        stackTrace: st,
      );
    }
  }

  @override
  Future<List<SupportTicket>> getMyTickets() async {
    try {
      debugPrint('[DEBUG SOPORTE] Obteniendo mis tickets');

      final response = await _client.get('/soporte-tickets/mios');

      if (response.statusCode == 200) {
        List<dynamic> data = [];
        if (response.data is List) {
          data = response.data as List<dynamic>;
        } else if (response.data is Map) {
          final Map<String, dynamic> responseMap =
              response.data as Map<String, dynamic>;
          if (responseMap.containsKey('content') &&
              responseMap['content'] is List) {
            data = responseMap['content'] as List<dynamic>;
          } else if (responseMap.containsKey('data') &&
              responseMap['data'] is List) {
            data = responseMap['data'] as List<dynamic>;
          }
        }

        return data.map((json) => SupportTicket.fromMap(json)).toList();
      } else {
        throw Exception('Error al obtener tickets');
      }
    } on DioException catch (e, st) {
      throwDioAsApp(e, fallback: 'Error al obtener tickets', stackTrace: st);
    }
  }
}
