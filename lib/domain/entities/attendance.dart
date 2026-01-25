class Attendance {
  final int id;
  final int membresiaId;
  final String membresiaNumeroSocio;
  final int clubId;
  final String clubNombre;
  final String fechaHora;
  final String fechaDia;
  final String estado;

  Attendance({
    required this.id,
    required this.membresiaId,
    required this.membresiaNumeroSocio,
    required this.clubId,
    required this.clubNombre,
    required this.fechaHora,
    required this.fechaDia,
    required this.estado,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] ?? 0,
      membresiaId: json['membresiaId'] ?? 0,
      membresiaNumeroSocio: json['membresiaNumeroSocio'] ?? '',
      clubId: json['clubId'] ?? 0,
      clubNombre: json['clubNombre'] ?? '',
      fechaHora: json['fechaHora'] ?? '',
      fechaDia: json['fechaDia'] ?? '',
      estado: json['estado'] ?? '',
    );
  }
}
