import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/sabor.dart';

class SaborRemoteDataSource {
  final Dio _client;

  SaborRemoteDataSource(this._client);

  /// Obtiene los sabores de un producto con su disponibilidad en un club.
  /// Endpoint: GET /api/clubes/{clubId}/productos/{productoId}/sabores
  Future<List<Sabor>> getSaboresDeProductoEnClub(int clubId, int productoId) async {
    try {
      final response = await _client.get('/clubes/$clubId/productos/$productoId/sabores');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => Sabor.fromMap(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[SABOR] Error getSaboresDeProductoEnClub: $e');
      rethrow;
    }
  }

  /// Toggle de disponibilidad de un sabor para un producto en un club.
  /// Endpoint: PATCH /api/clubes/{clubId}/productos/{productoId}/sabores/{saborId}/toggle
  Future<Sabor> toggleSaborEnClub(int clubId, int productoId, int saborId) async {
    try {
      final response = await _client.patch(
        '/clubes/$clubId/productos/$productoId/sabores/$saborId/toggle',
      );
      return Sabor.fromMap(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[SABOR] Error toggleSaborEnClub: $e');
      rethrow;
    }
  }
}
