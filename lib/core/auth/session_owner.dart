/// Identidad del usuario dueño de la sesión activa (para sync offline).
///
/// No sustituye a AuthProvider: solo evita que SyncService use un JWT de B
/// para pedidos persistidos de A.
class SessionOwner {
  String? _userId;

  String? get userId {
    final id = _userId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  bool get hasUser => userId != null;

  void setUserId(String? id) {
    final trimmed = id?.trim();
    _userId = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  void clear() => _userId = null;
}
