class Logro {
  final int id;
  final String nombre;
  final String descripcion;
  final String? iconoUrl;
  final int? tipoRequisito; // Cantidad de asistencias requeridas (logros automáticos)
  final String? estadoAprobacion; // APROBADO, PENDIENTE, RECHAZADO (para logros de club)
  final String? tipoMetrica; // CONSUMO, ASISTENCIA, REFERIDOS
  final int? metaCantidad;
  final int? puntosRecompensa;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  Logro({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.iconoUrl,
    this.tipoRequisito,
    this.estadoAprobacion,
    this.tipoMetrica,
    this.metaCantidad,
    this.puntosRecompensa,
    this.fechaInicio,
    this.fechaFin,
  });

  factory Logro.fromJson(Map<String, dynamic> json) {
    // tipoRequisito ahora es int (cantidad de asistencias)
    // Manejar tanto int como String (por compatibilidad temporal)
    int? parseTipoRequisito(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
        // Si es un string como "ASISTENCIAS_5", extraer el número
        final match = RegExp(r'(\d+)').firstMatch(value);
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
      }
      return null;
    }

    DateTime? parseFecha(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return Logro(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      iconoUrl: json['iconoUrl'] as String?,
      tipoRequisito: parseTipoRequisito(json['tipoRequisito']),
      estadoAprobacion: json['estadoAprobacion']?.toString(),
      tipoMetrica: json['tipoMetrica']?.toString(),
      metaCantidad: json['metaCantidad'] is int
          ? json['metaCantidad'] as int
          : int.tryParse(json['metaCantidad']?.toString() ?? ''),
      puntosRecompensa: json['puntosRecompensa'] is int
          ? json['puntosRecompensa'] as int
          : int.tryParse(json['puntosRecompensa']?.toString() ?? ''),
      fechaInicio: parseFecha(json['fechaInicio']),
      fechaFin: parseFecha(json['fechaFin']),
    );
  }
}

