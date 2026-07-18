/// Estado de sesión de la app (auth / expiración).
enum SessionStatus {
  /// Aún no se resolvió bootstrap.
  unknown,

  /// Usuario autenticado con JWT en memoria.
  active,

  /// Invalidación 401 en curso (single-flight).
  expiring,

  /// Sesión marcada como expirada (mensaje ya disparado).
  expired,

  /// Sin sesión / invitado.
  guest,
}
