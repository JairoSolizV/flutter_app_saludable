class CompraManual {
  final int id;
  final int membresiaId;
  final int clubId;
  final String descripcion;
  final double monto;
  final String fecha;
  final int registradaPorHostId;

  CompraManual({
    required this.id,
    required this.membresiaId,
    required this.clubId,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    required this.registradaPorHostId,
  });

  factory CompraManual.fromJson(Map<String, dynamic> json) {
    return CompraManual(
      id: json['id'] as int,
      membresiaId: json['membresiaId'] as int,
      clubId: json['clubId'] as int,
      descripcion: json['descripcion']?.toString() ?? '',
      monto: (json['monto'] as num).toDouble(),
      fecha: json['fecha']?.toString() ?? '',
      registradaPorHostId: json['registradaPorHostId'] as int? ?? 0,
    );
  }
}
