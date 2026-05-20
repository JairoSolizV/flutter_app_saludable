class MisionPreSocio {
  final int id;
  final int preSocioId;
  final String nombre;
  final String? descripcion;
  final int metaCantidad;
  final int progresoActual;
  final String? fechaLimite;
  final bool completada;

  MisionPreSocio({
    required this.id,
    required this.preSocioId,
    required this.nombre,
    this.descripcion,
    required this.metaCantidad,
    required this.progresoActual,
    this.fechaLimite,
    required this.completada,
  });

  double get porcentaje =>
      metaCantidad == 0 ? 0.0 : (progresoActual / metaCantidad).clamp(0.0, 1.0);

  factory MisionPreSocio.fromJson(Map<String, dynamic> json) {
    return MisionPreSocio(
      id: json['id'] as int,
      preSocioId: json['prospectoId'] as int, // Keeps prospectoId for backend mapping
      nombre: json['nombre']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
      metaCantidad: json['metaCantidad'] as int? ?? 1,
      progresoActual: json['progresoActual'] as int? ?? 0,
      fechaLimite: json['fechaLimite']?.toString(),
      completada: json['completada'] as bool? ?? false,
    );
  }
}
