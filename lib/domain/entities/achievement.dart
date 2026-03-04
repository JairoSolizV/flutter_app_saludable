class Achievement {
  final String id;
  final String title;
  final String description;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String tipoMetrica; // 'CONSUMO', 'ASISTENCIA', 'REFERIDOS'
  final int metaCantidad;
  final int puntosRecompensa;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.fechaInicio,
    required this.fechaFin,
    required this.tipoMetrica,
    required this.metaCantidad,
    required this.puntosRecompensa,
  });

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      fechaInicio: map['fechaInicio'] != null 
          ? DateTime.parse(map['fechaInicio'])
          : DateTime.now(),
      fechaFin: map['fechaFin'] != null 
          ? DateTime.parse(map['fechaFin'])
          : DateTime.now().add(const Duration(days: 30)),
      tipoMetrica: map['tipoMetrica'] ?? 'ASISTENCIA',
      metaCantidad: map['metaCantidad'] ?? 10,
      puntosRecompensa: map['puntosRecompensa'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'fechaInicio': fechaInicio.toIso8601String(),
      'fechaFin': fechaFin.toIso8601String(),
      'tipoMetrica': tipoMetrica,
      'metaCantidad': metaCantidad,
      'puntosRecompensa': puntosRecompensa,
    };
  }
}
