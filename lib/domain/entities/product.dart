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
    return Product(
      id: map['id'].toString(),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      category: map['category'] ?? 'General',
      imageUrl: map['image_url'] ?? '',
      hubId: map['hubId'],
      active: map['active'] ?? true,
      available: map['disponible'] ?? false,
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
