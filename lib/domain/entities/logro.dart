class Logro {
  final int id;
  final String nombre;
  final String descripcion;
  final String? iconoUrl;
  final String? tipoRequisito;

  Logro({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.iconoUrl,
    this.tipoRequisito,
  });

  factory Logro.fromJson(Map<String, dynamic> json) {
    return Logro(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      iconoUrl: json['iconoUrl'] as String?,
      tipoRequisito: json['tipoRequisito'] as String?,
    );
  }
}

