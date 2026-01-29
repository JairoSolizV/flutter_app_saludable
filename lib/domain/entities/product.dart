class Product {
  final String id;
  final String name;
  final String description;
  final double price; // Optional for now
  final String category;
  final String imageUrl;
  final int? hubId;
  final bool active; // Global status
  final bool available; // Local club status (disponible)

  Product({
    required this.id,
    required this.name,
    required this.description,
    this.price = 0.0,
    this.category = 'General',
    this.imageUrl = '',
    this.hubId,
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
    
    return Product(
      id: productId,
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      price: (map['price'] ?? 0).toDouble(),
      category: map['category']?.toString() ?? 'General',
      imageUrl: map['image_url']?.toString() ?? '',
      hubId: hubId,
      active: map['active'] == true || map['active'] == 1,
      available: available, // false si es null, true/false según el valor
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'image_url': imageUrl,
      'hubId': hubId,
      'active': active,
      'disponible': available,
    };
  }
}
