import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/combo.dart';

class ComboRemoteDataSource {
  final Dio _client;

  ComboRemoteDataSource(this._client);

  /// Lista todos los combos de un club.
  /// GET /api/clubes/{clubId}/combos
  Future<List<Combo>> getCombosByClub(int clubId) async {
    try {
      final response = await _client.get('/clubes/$clubId/combos');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => Combo.fromMap(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[COMBO] Error getCombosByClub: $e');
      rethrow;
    }
  }

  /// Obtiene un combo por su ID.
  /// GET /api/clubes/{clubId}/combos/{comboId}
  Future<Combo> getCombo(int clubId, int comboId) async {
    try {
      final response = await _client.get('/clubes/$clubId/combos/$comboId');
      return Combo.fromMap(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[COMBO] Error getCombo: $e');
      rethrow;
    }
  }

  /// Crea un nuevo combo.
  /// POST /api/clubes/{clubId}/combos
  Future<Combo> createCombo(int clubId, {
    required String nombre,
    String? descripcion,
    String? imagenUrl,
    int? puntosValor,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final body = <String, dynamic>{
        'nombre': nombre,
        if (descripcion != null) 'descripcion': descripcion,
        if (imagenUrl != null) 'imagenUrl': imagenUrl,
        if (puntosValor != null) 'puntosValor': puntosValor,
        'items': items,
      };
      final response = await _client.post('/clubes/$clubId/combos', data: body);
      return Combo.fromMap(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[COMBO] Error createCombo: $e');
      rethrow;
    }
  }

  /// Actualiza un combo existente.
  /// PUT /api/clubes/{clubId}/combos/{comboId}
  Future<Combo> updateCombo(int clubId, int comboId, {
    required String nombre,
    String? descripcion,
    String? imagenUrl,
    int? puntosValor,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final body = <String, dynamic>{
        'nombre': nombre,
        if (descripcion != null) 'descripcion': descripcion,
        if (imagenUrl != null) 'imagenUrl': imagenUrl,
        if (puntosValor != null) 'puntosValor': puntosValor,
        'items': items,
      };
      final response = await _client.put('/clubes/$clubId/combos/$comboId', data: body);
      return Combo.fromMap(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[COMBO] Error updateCombo: $e');
      rethrow;
    }
  }

  /// Toggle activo/inactivo de un combo.
  /// PATCH /api/clubes/{clubId}/combos/{comboId}/toggle
  Future<Combo> toggleCombo(int clubId, int comboId) async {
    try {
      final response = await _client.patch('/clubes/$clubId/combos/$comboId/toggle');
      return Combo.fromMap(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[COMBO] Error toggleCombo: $e');
      rethrow;
    }
  }

  /// Elimina un combo.
  /// DELETE /api/clubes/{clubId}/combos/{comboId}
  Future<void> deleteCombo(int clubId, int comboId) async {
    try {
      await _client.delete('/clubes/$clubId/combos/$comboId');
    } catch (e) {
      debugPrint('[COMBO] Error deleteCombo: $e');
      rethrow;
    }
  }
}
