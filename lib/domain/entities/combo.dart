class ComboItem {
  final int? id;
  final int productoId;
  final String productoNombre;
  final String? productoImagenUrl;
  final int? puntosValorProducto;
  final int? saborId;
  final String? saborNombre;
  final int cantidad;

  ComboItem({
    this.id,
    required this.productoId,
    required this.productoNombre,
    this.productoImagenUrl,
    this.puntosValorProducto,
    this.saborId,
    this.saborNombre,
    this.cantidad = 1,
  });

  factory ComboItem.fromMap(Map<String, dynamic> map) {
    return ComboItem(
      id: map['id'] as int?,
      productoId: map['productoId'] is int
          ? map['productoId']
          : int.tryParse(map['productoId'].toString()) ?? 0,
      productoNombre: map['productoNombre']?.toString() ?? '',
      productoImagenUrl: map['productoImagenUrl']?.toString(),
      puntosValorProducto: map['puntosValorProducto'] as int?,
      saborId: map['saborId'] as int?,
      saborNombre: map['saborNombre']?.toString(),
      cantidad: map['cantidad'] is int
          ? map['cantidad']
          : int.tryParse(map['cantidad'].toString()) ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'productoId': productoId,
      'productoNombre': productoNombre,
      if (productoImagenUrl != null) 'productoImagenUrl': productoImagenUrl,
      if (puntosValorProducto != null) 'puntosValorProducto': puntosValorProducto,
      if (saborId != null) 'saborId': saborId,
      if (saborNombre != null) 'saborNombre': saborNombre,
      'cantidad': cantidad,
    };
  }
}

class Combo {
  final int? id;
  final int clubId;
  final String? clubNombre;
  final String nombre;
  final String? descripcion;
  final String? imagenUrl;
  final int puntosValor;
  final bool activo;
  final List<ComboItem> items;

  Combo({
    this.id,
    required this.clubId,
    this.clubNombre,
    required this.nombre,
    this.descripcion,
    this.imagenUrl,
    this.puntosValor = 0,
    this.activo = true,
    this.items = const [],
  });

  factory Combo.fromMap(Map<String, dynamic> map) {
    return Combo(
      id: map['id'] as int?,
      clubId: map['clubId'] is int
          ? map['clubId']
          : int.tryParse(map['clubId'].toString()) ?? 0,
      clubNombre: map['clubNombre']?.toString(),
      nombre: map['nombre']?.toString() ?? '',
      descripcion: map['descripcion']?.toString(),
      imagenUrl: map['imagenUrl']?.toString(),
      puntosValor: map['puntosValor'] is int
          ? map['puntosValor']
          : int.tryParse(map['puntosValor'].toString()) ?? 0,
      activo: map['activo'] == true,
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => ComboItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'clubId': clubId,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (imagenUrl != null) 'imagenUrl': imagenUrl,
      'puntosValor': puntosValor,
      'activo': activo,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  Combo copyWith({
    int? id,
    int? clubId,
    String? clubNombre,
    String? nombre,
    String? descripcion,
    String? imagenUrl,
    int? puntosValor,
    bool? activo,
    List<ComboItem>? items,
  }) {
    return Combo(
      id: id ?? this.id,
      clubId: clubId ?? this.clubId,
      clubNombre: clubNombre ?? this.clubNombre,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      puntosValor: puntosValor ?? this.puntosValor,
      activo: activo ?? this.activo,
      items: items ?? this.items,
    );
  }
}
