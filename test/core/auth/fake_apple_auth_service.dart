import 'package:flutter_app_saludable/core/auth/apple_auth_service.dart';

/// Fake para tests: no abre el sheet nativo de Apple.
class FakeAppleAuthService extends AppleAuthService {
  FakeAppleAuthService({
    this.credentials,
    this.throwOnSignIn,
  });

  /// Credenciales que [signIn] devolverá. `null` simula cancelación.
  final AppleAuthCredentials? credentials;

  /// Si no es null, [signIn] lanza esta excepción.
  final Object? throwOnSignIn;

  int signInCalls = 0;

  @override
  Future<AppleAuthCredentials?> signIn() async {
    signInCalls++;
    if (throwOnSignIn != null) {
      throw throwOnSignIn!;
    }
    return credentials;
  }
}
