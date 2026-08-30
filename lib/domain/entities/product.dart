import 'product_option.dart';

export 'product_option.dart';

class Product {
  static const Object _unset = Object();

  final String id;
  final String name;
  final String description;

  /// Precio base / sugerido (`precio`). SQLite persiste este campo como `price`.
  final double price;

  /// Precio efectivo de venta (`precioEfectivo` = club ?? base). Remote-only.
  final double effectivePrice;

  /// Override del club (`precioVentaClub`). Null = usar precio base. Remote-only.
  final double? clubSalePrice;

  final int puntosValor; // Fidelización — no es precio.
  final String category;
  final String imageUrl;
  final int? hubId;
  final int? clubCreadorId;
  final String tipo; // 'GLOBAL' o 'LOCAL'
  final String estadoAprobacion; // 'APROBADO', 'PENDIENTE', 'RECHAZADO'
  final bool active; // Global status
  final bool available; // Local club status (disponible)

  /// Campos de propuesta/revisión. Remotos: no se persisten en SQLite (`toMap`).
  final String? ingredientes;
  final String? comentarioRevision;
  final int? revisadoPorUsuarioId;
  final String? revisadoPorNombre;
  final DateTime? revisadoAt;

  /// Definición estructural de grupos/opciones. Remote-only.
  final List<ProductOptionGroup>? optionGroups;

  Product({
    required this.id,
    required this.name,
    required this.description,
    this.price = 0.0,
    double? effectivePrice,
    this.clubSalePrice,
    this.puntosValor = 0,
    this.category = 'General',
    this.imageUrl = '',
    this.hubId,
    this.clubCreadorId,
    this.tipo = 'GLOBAL',
    this.estadoAprobacion = 'APROBADO',
    this.active = true,
    this.available = false,
    this.ingredientes,
    this.comentarioRevision,
    this.revisadoPorUsuarioId,
    this.revisadoPorNombre,
    this.revisadoAt,
    this.optionGroups,
  }) : effectivePrice = effectivePrice ?? price;

  bool get isLocal => tipo.toUpperCase() == 'LOCAL';

  bool get isGlobal => tipo.toUpperCase() == 'GLOBAL';

  String get estadoNormalizado => estadoAprobacion.toUpperCase();

  bool get isRechazado => estadoNormalizado == 'RECHAZADO';

  bool get isPendiente => estadoNormalizado == 'PENDIENTE';

  bool get isAprobado => estadoNormalizado == 'APROBADO';

  /// Hay definición estructural para que el socio configure el producto.
  bool get hasConfigurableOptionGroups =>
      optionGroups != null && optionGroups!.isNotEmpty;

  /// Listado activo del anfitrión: detalle de definición, no sabores legacy.
  bool get shouldOpenHostReview => isLocal || isGlobal;

  /// LOCAL APROBADO del club del anfitrión: puede editar la definición estructural.
  bool canHostEditDefinition(int clubId) =>
      isLocal && isAprobado && clubCreadorId == clubId;

  /// APROBADO (LOCAL o GLOBAL): el anfitrión puede fijar precio de venta del club.
  bool get canHostSetClubSalePrice => isAprobado;

  /// Backend rechaza pedidos con precio efectivo <= 0.
  bool get hasConfiguredSalePrice => effectivePrice > 0;

  factory Product.fromMap(Map<String, dynamic> map) {
    // Manejar el id correctamente: puede venir como int o String
    final dynamic idValue = map['id'];
    final String productId = idValue is int ? idValue.toString() : (idValue?.toString() ?? '');
    
    // Manejar hubId correctamente: puede venir como int o null
    final dynamic hubIdValue = map['hubId'];
    final int? hubId = hubIdValue is int ? hubIdValue : (hubIdValue != null ? int.tryParse(hubIdValue.toString()) : null);
    
    // Manejar disponible: null significa que no hay relación, debe ser false por defecto
    final dynamic disponibleValue = map['disponible'];
    final bool available = disponibleValue == true || disponibleValue == 1;

    // Manejar clubCreadorId para separar globales de propios
    final dynamic clubIdValue = map['clubCreadorId'] ?? map['club_creador_id'] ?? map['clubId'] ?? map['club_id'];
    final int? clubIdParsed = clubIdValue is int ? clubIdValue : (clubIdValue != null ? int.tryParse(clubIdValue.toString()) : null);
    
    final prices = ProductPrices.fromJson(map);
    return Product(
      id: productId,
      name: map['name']?.toString() ?? map['nombre']?.toString() ?? '',
      description: map['description']?.toString() ?? map['descripcion']?.toString() ?? '',
      price: prices.price,
      effectivePrice: prices.effectivePrice,
      clubSalePrice: prices.clubSalePrice,
      puntosValor: map['puntosValor'] is int ? map['puntosValor'] as int : (int.tryParse(map['puntosValor']?.toString() ?? '0') ?? 0),
      category: map['category']?.toString() ?? 'General',
      imageUrl: map['imagenUrl']?.toString() ?? map['image_url']?.toString() ?? '',
      hubId: hubId,
      clubCreadorId: clubIdParsed,
      tipo: map['tipo']?.toString() ?? 'GLOBAL',
      estadoAprobacion: map['estadoAprobacion']?.toString() ?? 'APROBADO',
      active: map['active'] == true || map['activo'] == true || map['active'] == 1 || map['activo'] == 1,
      available: available, // false si es null, true/false según el valor
      ingredientes: _optionalString(map['ingredientes']),
      comentarioRevision: _optionalString(map['comentarioRevision']),
      revisadoPorUsuarioId: _optionalInt(map['revisadoPorUsuarioId']),
      revisadoPorNombre: _optionalString(map['revisadoPorNombre']),
      revisadoAt: _optionalDateTime(map['revisadoAt']),
      optionGroups: ProductOptionGroup.listFromJson(map['gruposOpciones']),
    );
  }

  /// Solo columnas SQLite existentes. Revisión y optionGroups son remote-only.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'puntosValor': puntosValor,
      'category': category,
      'image_url': imageUrl,
      'hubId': hubId,
      'clubCreadorId': clubCreadorId,
      'tipo': tipo,
      'estadoAprobacion': estadoAprobacion,
      'active': active ? 1 : 0,
      'disponible': available ? 1 : 0,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    double? effectivePrice,
    Object? clubSalePrice = _unset,
    int? puntosValor,
    String? category,
    String? imageUrl,
    int? hubId,
    int? clubCreadorId,
    String? tipo,
    String? estadoAprobacion,
    bool? active,
    bool? available,
    String? ingredientes,
    String? comentarioRevision,
    int? revisadoPorUsuarioId,
    String? revisadoPorNombre,
    DateTime? revisadoAt,
    List<ProductOptionGroup>? optionGroups,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      effectivePrice: effectivePrice ?? this.effectivePrice,
      clubSalePrice: identical(clubSalePrice, _unset)
          ? this.clubSalePrice
          : clubSalePrice as double?,
      puntosValor: puntosValor ?? this.puntosValor,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      hubId: hubId ?? this.hubId,
      clubCreadorId: clubCreadorId ?? this.clubCreadorId,
      tipo: tipo ?? this.tipo,
      estadoAprobacion: estadoAprobacion ?? this.estadoAprobacion,
      active: active ?? this.active,
      available: available ?? this.available,
      ingredientes: ingredientes ?? this.ingredientes,
      comentarioRevision: comentarioRevision ?? this.comentarioRevision,
      revisadoPorUsuarioId: revisadoPorUsuarioId ?? this.revisadoPorUsuarioId,
      revisadoPorNombre: revisadoPorNombre ?? this.revisadoPorNombre,
      revisadoAt: revisadoAt ?? this.revisadoAt,
      optionGroups: optionGroups ?? this.optionGroups,
    );
  }

  static String? _optionalString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _optionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime? _optionalDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

/// Parseo de `precio` / `precioEfectivo` / `precioVentaClub` (y `price` legacy).
class ProductPrices {
  final double price;
  final double effectivePrice;
  final double? clubSalePrice;

  const ProductPrices({
    required this.price,
    required this.effectivePrice,
    required this.clubSalePrice,
  });

  factory ProductPrices.fromJson(Map<String, dynamic> map) {
    final price = _parseDouble(map['precio'] ?? map['price']) ?? 0;
    final clubSalePrice = map.containsKey('precioVentaClub')
        ? _parseDouble(map['precioVentaClub'])
        : null;
    final effectivePrice = map.containsKey('precioEfectivo') &&
            map['precioEfectivo'] != null
        ? (_parseDouble(map['precioEfectivo']) ?? price)
        : price;
    return ProductPrices(
      price: price,
      effectivePrice: effectivePrice,
      clubSalePrice: clubSalePrice,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
}
