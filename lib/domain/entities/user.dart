import 'dart:convert';

/// Perfil de usuario de la app.
///
/// [token] es **transitorio en memoria** (respuesta de login / hidratación desde
/// [TokenStore]). **No** se persiste en SQLite: ver [toMap].
class User {
  final String id;
  final String name;
  final String email;
  final String role; // 'guest', 'member', 'host'
  final String? token;
  final String? phone;
  final String? photoUrl;
  final String? birthDate;
  final Map<String, dynamic>? socialMedia;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.token,
    this.phone,
    this.photoUrl,
    this.birthDate,
    this.socialMedia,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      role: map['role'],
      // JWT ya no se hidrata desde SQLite (columna legacy solo para migración).
      token: null,
      phone: map['phone'],
      photoUrl: map['photo_url'],
      birthDate: map['birth_date'],
      socialMedia: map['social_media'] != null
          ? (map['social_media'] is String
              ? jsonDecode(map['social_media'])
              : map['social_media'])
          : null,
    );
  }

  /// Persistencia de perfil. El JWT siempre se guarda como null en SQLite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'token': null,
      'phone': phone,
      'photo_url': photoUrl,
      'birth_date': birthDate,
      'social_media': socialMedia != null ? jsonEncode(socialMedia) : null,
    };
  }

  User copyWith({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? birthDate,
    Map<String, dynamic>? socialMedia,
    String? token,
    bool clearToken = false,
  }) {
    return User(
      id: id,
      role: role,
      token: clearToken ? null : (token ?? this.token),
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      birthDate: birthDate ?? this.birthDate,
      socialMedia: socialMedia ?? this.socialMedia,
    );
  }

  /// Perfil sin JWT (para persistir en SQLite).
  User withoutToken() => copyWith(clearToken: true);
}
