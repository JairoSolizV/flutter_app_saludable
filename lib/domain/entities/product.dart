class Product {
  final String id;
  final String name;
  final String description;
  final double price; // Optional/legacy
  final int puntosValor; // MR QUILLO Points
  final String category;
  final String imageUrl;
  final int? hubId;
  final int? clubCreadorId;
  final bool active; // Global status
  final bool available; // Local club status (disponible)

  Product({
    required this.id,
    required this.name,
    required this.description,
    this.price = 0.0,
    this.puntosValor = 0,
    this.category = 'General',
    this.imageUrl = '',
    this.hubId,
    this.clubCreadorId,
    this.active = true,
    this.available = false,
  });

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
    
    return Product(
      id: productId,
      name: map['name']?.toString() ?? map['nombre']?.toString() ?? '',
      description: map['description']?.toString() ?? map['descripcion']?.toString() ?? '',
      price: (map['price'] ?? 0).toDouble(),
      puntosValor: map['puntosValor'] ?? 0,
      category: map['category']?.toString() ?? 'General',
      imageUrl: map['image_url']?.toString() ?? '',
      hubId: hubId,
      clubCreadorId: clubIdParsed,
      active: map['active'] == true || map['activo'] == true || map['active'] == 1 || map['activo'] == 1,
      available: available, // false si es null, true/false según el valor
    );
  }

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
      'active': active ? 1 : 0,
      'disponible': available ? 1 : 0,
    };
  }
}
