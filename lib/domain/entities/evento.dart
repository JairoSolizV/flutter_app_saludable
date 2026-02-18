import 'package:flutter/foundation.dart';

class Evento {
  final int id;
  final int? hubId;
  final String? hubNombre;
  final int? clubId;
  final String? clubNombre;
  final String nombre;
  final DateTime fechaEvento;
  final String descripcion;

  Evento({
    required this.id,
    this.hubId,
    this.hubNombre,
    this.clubId,
    this.clubNombre,
    required this.nombre,
    required this.fechaEvento,
    required this.descripcion,
  });

  factory Evento.fromJson(Map<String, dynamic> json) {
    // Parsear fechaEvento (puede venir como String en formato ISO, LocalDate YYYY-MM-DD, o como número timestamp)
    DateTime parseFechaEvento() {
      // El backend puede enviar 'fechaEvento' o 'fecha'
      final fechaValue = json['fechaEvento'] ?? json['fecha'];
      
      if (fechaValue == null) {
        debugPrint('[EVENTO] WARNING: fechaEvento es null, usando fecha actual');
        return DateTime.now();
      }
      
      if (fechaValue is String) {
        final fechaStr = fechaValue.trim();
        
        // Si está vacío, retornar fecha actual
        if (fechaStr.isEmpty) {
          debugPrint('[EVENTO] WARNING: fechaEvento está vacío, usando fecha actual');
          return DateTime.now();
        }
        
        // Intentar parsear como ISO 8601 completo (con T y hora)
        if (fechaStr.contains('T')) {
          final parsed = DateTime.tryParse(fechaStr);
          if (parsed != null) {
            debugPrint('[EVENTO] Fecha parseada (ISO): $fechaStr -> $parsed');
            return parsed;
          }
        }
        
        // Si es solo fecha (YYYY-MM-DD), agregar hora medianoche UTC y convertir a local
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fechaStr)) {
          // Parsear como UTC y luego convertir a local
          final parsed = DateTime.tryParse('${fechaStr}T00:00:00Z');
          if (parsed != null) {
            // Convertir de UTC a hora local
            final localDate = DateTime(
              parsed.year,
              parsed.month,
              parsed.day,
            );
            debugPrint('[EVENTO] Fecha parseada (YYYY-MM-DD): $fechaStr -> $localDate');
            return localDate;
          }
        }
        
        // Intentar parsear directamente
        final parsed = DateTime.tryParse(fechaStr);
        if (parsed != null) {
          debugPrint('[EVENTO] Fecha parseada (directa): $fechaStr -> $parsed');
          return parsed;
        }
        
        debugPrint('[EVENTO] ERROR: No se pudo parsear fecha: $fechaStr');
        return DateTime.now();
      }
      
      // Si es un número (timestamp)
      if (fechaValue is num) {
        final timestamp = fechaValue.toInt();
        final parsed = DateTime.fromMillisecondsSinceEpoch(timestamp);
        debugPrint('[EVENTO] Fecha parseada (timestamp): $timestamp -> $parsed');
        return parsed;
      }
      
      debugPrint('[EVENTO] ERROR: Tipo de fecha no reconocido: ${fechaValue.runtimeType}');
      return DateTime.now();
    }

    return Evento(
      id: json['id'] as int,
      hubId: json['hubId'] as int?,
      hubNombre: json['hubNombre'] as String?,
      clubId: json['clubId'] as int?,
      clubNombre: json['clubNombre'] as String?,
      nombre: json['nombre'] as String? ?? '',
      fechaEvento: parseFechaEvento(),
      descripcion: json['descripcion'] as String? ?? '',
    );
  }
}

