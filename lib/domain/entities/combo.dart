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
  final double price;
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
    this.price = 0,
    this.activo = true,
    this.items = const [],
  });

  bool get hasConfiguredPrice => price > 0;

  bool get isPurchasable => activo && hasConfiguredPrice;

  /// Resumen para catálogo: `Batido · Té · Aloe`
  String get includesCatalogSummary =>
      items.map((i) => i.productoNombre).join(' · ');

  /// Suma de precios efectivos de referencia (solo UI host).
  static double referenceSeparateTotal(
    Iterable<ComboItem> items,
    double Function(int productoId) unitPriceFor,
  ) {
    var total = 0.0;
    for (final item in items) {
      total += unitPriceFor(item.productoId) * item.cantidad;
    }
    return total;
  }

  String get itemsSummary => items
      .map((i) {
        final label = i.cantidad > 1 ? '${i.cantidad}x ${i.productoNombre}' : i.productoNombre;
        return label;
      })
      .join(' + ');

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
      price: _parsePrice(map['precio'] ?? map['price']),
      activo: map['activo'] == true,
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => ComboItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'clubId': clubId,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (imagenUrl != null) 'imagenUrl': imagenUrl,
      'puntosValor': puntosValor,
      'precio': price,
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
    double? price,
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
      price: price ?? this.price,
      activo: activo ?? this.activo,
      items: items ?? this.items,
    );
  }
}
