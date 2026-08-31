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

  /// Parsea `fechaEvento` del backend (`LocalDate` → `YYYY-MM-DD`).
  ///
  /// Retorna `null` si el valor es inválido; no fabrica fechas silenciosas.
  static DateTime? parseFechaEventoValue(dynamic fechaValue) {
    if (fechaValue == null) {
      debugPrint('[EVENTO] fechaEvento null — registro inválido');
      return null;
    }

    if (fechaValue is String) {
      final fechaStr = fechaValue.trim();
      if (fechaStr.isEmpty) {
        debugPrint('[EVENTO] fechaEvento vacío — registro inválido');
        return null;
      }

      final localDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(fechaStr);
      if (localDate != null) {
        final year = int.parse(localDate.group(1)!);
        final month = int.parse(localDate.group(2)!);
        final day = int.parse(localDate.group(3)!);
        return DateTime(year, month, day);
      }

      if (fechaStr.contains('T')) {
        final parsed = DateTime.tryParse(fechaStr);
        if (parsed != null) {
          return DateTime(parsed.year, parsed.month, parsed.day);
        }
      }

      final parsed = DateTime.tryParse(fechaStr);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }

      debugPrint('[EVENTO] No se pudo parsear fecha: $fechaStr');
      return null;
    }

    if (fechaValue is num) {
      final parsed = DateTime.fromMillisecondsSinceEpoch(fechaValue.toInt());
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    debugPrint(
      '[EVENTO] Tipo de fecha no reconocido: ${fechaValue.runtimeType}',
    );
    return null;
  }

  /// Día de calendario local (sin hora).
  static DateTime calendarDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Incluye hoy y fechas futuras; excluye días anteriores a [reference].
  static bool isOnOrAfterToday(DateTime eventDate, DateTime reference) {
    final today = calendarDay(reference);
    final eventDay = calendarDay(eventDate);
    return !eventDay.isBefore(today);
  }

  /// Filtra y ordena eventos de hoy en adelante (ascendente por fecha).
  static List<Evento> filterUpcoming(
    List<Evento> eventos,
    DateTime reference,
  ) {
    final upcoming = eventos
        .where((evento) => isOnOrAfterToday(evento.fechaEvento, reference))
        .toList();
    upcoming.sort((a, b) => a.fechaEvento.compareTo(b.fechaEvento));
    return upcoming;
  }

  factory Evento.fromJson(Map<String, dynamic> json) {
    final fechaValue = json['fechaEvento'] ?? json['fecha'];
    final fecha = parseFechaEventoValue(fechaValue);
    if (fecha == null) {
      throw FormatException('fechaEvento inválida: $fechaValue');
    }

    return Evento(
      id: json['id'] as int,
      hubId: json['hubId'] as int?,
      hubNombre: json['hubNombre'] as String?,
      clubId: json['clubId'] as int?,
      clubNombre: json['clubNombre'] as String?,
      nombre: json['nombre'] as String? ?? '',
      fechaEvento: fecha,
      descripcion: json['descripcion'] as String? ?? '',
    );
  }
}
