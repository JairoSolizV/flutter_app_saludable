/// Error controlado del almacenamiento seguro de sesión.
///
/// Nunca debe incluir JWT, headers Authorization ni secretos en [message].
class SecureStorageException implements Exception {
  SecureStorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'SecureStorageException: $message';
}
