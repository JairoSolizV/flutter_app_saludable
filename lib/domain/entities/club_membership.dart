class ClubMembership {
  final int id;
  final int usuarioId;
  final String usuarioNombre;
  final int clubId;
  final String clubNombre;
  final int nivelId;
  final String nivelNombre;
  final String numeroSocio;
  final int puntosAcumulados;
  final String fechaRegistro;
  final String estado;

  ClubMembership({
    required this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.clubId,
    required this.clubNombre,
    required this.nivelId,
    required this.nivelNombre,
    required this.numeroSocio,
    required this.puntosAcumulados,
    required this.fechaRegistro,
    required this.estado,
  });

  factory ClubMembership.fromJson(Map<String, dynamic> json) {
    return ClubMembership(
      id: json['id'],
      usuarioId: json['usuarioId'],
      usuarioNombre: json['usuarioNombre'] ?? 'Sin Nombre',
      clubId: json['clubId'],
      clubNombre: json['clubNombre'] ?? '',
      nivelId: json['nivelId'] ?? 0,
      nivelNombre: json['nivelNombre'] ?? 'Socio',
      numeroSocio: json['numeroSocio'] ?? '',
      puntosAcumulados: json['puntosAcumulados'] ?? 0,
      fechaRegistro: json['fechaRegistro'] ?? '',
      estado: json['estado'] ?? 'ACTIVO',
    );
  }
}
