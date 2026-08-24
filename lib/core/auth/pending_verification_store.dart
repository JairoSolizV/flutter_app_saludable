/// Persistencia local del email pendiente de verificación OTP.
abstract class PendingVerificationStore {
  Future<void> save(String email);
  Future<String?> read();
  Future<void> clear();
}
