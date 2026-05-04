class MisionProspecto {
  final int id;
  final int prospectoId;
  final String nombre;
  final String? descripcion;
  final int metaCantidad;
  final int progresoActual;
  final String? fechaLimite;
  final bool completada;

  MisionProspecto({
    required this.id,
    required this.prospectoId,
    required this.nombre,
    this.descripcion,
    required this.metaCantidad,
    required this.progresoActual,
    this.fechaLimite,
    required this.completada,
  });

  double get porcentaje =>
      metaCantidad == 0 ? 0.0 : (progresoActual / metaCantidad).clamp(0.0, 1.0);

  factory MisionProspecto.fromJson(Map<String, dynamic> json) {
    return MisionProspecto(
      id: json['id'] as int,
      prospectoId: json['prospectoId'] as int,
      nombre: json['nombre']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
      metaCantidad: json['metaCantidad'] as int? ?? 1,
      progresoActual: json['progresoActual'] as int? ?? 0,
      fechaLimite: json['fechaLimite']?.toString(),
      completada: json['completada'] as bool? ?? false,
    );
  }
}
