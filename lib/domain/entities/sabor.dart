class Sabor {
  final int id;
  final String nombre;
  final bool disponible;

  Sabor({
    required this.id,
    required this.nombre,
    this.disponible = false,
  });

  factory Sabor.fromMap(Map<String, dynamic> map) {
    return Sabor(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      nombre: map['nombre']?.toString() ?? '',
      disponible: map['disponible'] == true || map['disponible'] == 1 || map['disponible'] == '1' || map['disponible'] == 'true',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'disponible': disponible,
    };
  }
}
