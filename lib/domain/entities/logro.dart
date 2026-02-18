class Logro {
  final int id;
  final String nombre;
  final String descripcion;
  final String? iconoUrl;
  final int? tipoRequisito; // Cambiado de String? a int? (cantidad de asistencias requeridas)

  Logro({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.iconoUrl,
    this.tipoRequisito,
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

    return Logro(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      iconoUrl: json['iconoUrl'] as String?,
      tipoRequisito: parseTipoRequisito(json['tipoRequisito']),
    );
  }
}

