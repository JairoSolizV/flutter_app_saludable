import 'mision_prospecto.dart';

class Prospecto {
  final int id;
  final int clubId;
  final String nombre;
  final String telefono;
  final int? referidoPorMembresiaId;
  final String? referidoPorNombre;
  final String fechaCreacion;
  final String estado;
  final List<MisionProspecto> misiones;

  Prospecto({
    required this.id,
    required this.clubId,
    required this.nombre,
    required this.telefono,
    this.referidoPorMembresiaId,
    this.referidoPorNombre,
    required this.fechaCreacion,
    required this.estado,
    this.misiones = const [],
  });

  bool get todasMisionesCompletas =>
      misiones.isNotEmpty && misiones.every((m) => m.completada);

  double get progresoGlobal {
    if (misiones.isEmpty) return 0.0;
    final completas = misiones.where((m) => m.completada).length;
    return completas / misiones.length;
  }

  factory Prospecto.fromJson(Map<String, dynamic> json) {
    final misionesJson = json['misiones'] as List<dynamic>? ?? [];
    return Prospecto(
      id: json['id'] as int,
      clubId: json['clubId'] as int,
      nombre: json['nombre']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      referidoPorMembresiaId: json['referidoPorMembresiaId'] as int?,
      referidoPorNombre: json['referidoPorNombre']?.toString(),
      fechaCreacion: json['fechaCreacion']?.toString() ?? '',
      estado: json['estado']?.toString() ?? 'EN_SEGUIMIENTO',
      misiones: misionesJson
          .map((e) => MisionProspecto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
