import 'dart:convert';

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
      token: map['token'],
      phone: map['phone'],
      photoUrl: map['photo_url'],
      birthDate: map['birth_date'],
      socialMedia: map['social_media'] != null 
        ? (map['social_media'] is String ? jsonDecode(map['social_media']) : map['social_media']) 
        : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'token': token,
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
  }) {
    return User(
      id: id,
      role: role,
      token: token,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      birthDate: birthDate ?? this.birthDate,
      socialMedia: socialMedia ?? this.socialMedia,
    );
  }
}
