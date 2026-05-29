class ArbolReferidos {
  final int membresiaId;
  final String numeroSocio;
  final String nombreCompleto;
  final int puntosAcumulados;
  final String estado;
  final String? clubNombre;
  final List<ArbolReferidos> referidos;

  ArbolReferidos({
    required this.membresiaId,
    required this.numeroSocio,
    required this.nombreCompleto,
    required this.puntosAcumulados,
    required this.estado,
    this.clubNombre,
    required this.referidos,
  });

  factory ArbolReferidos.fromJson(Map<String, dynamic> json) {
    return ArbolReferidos(
      membresiaId: json['membresiaId'],
      numeroSocio: json['numeroSocio'] ?? '',
      nombreCompleto: json['nombreCompleto'] ?? '',
      puntosAcumulados: json['puntosAcumulados'] ?? 0,
      estado: json['estado'] ?? '',
      clubNombre: json['clubNombre'],
      referidos: (json['referidos'] as List<dynamic>?)
              ?.map((r) => ArbolReferidos.fromJson(r))
              .toList() ??
          [],
    );
  }
}
