import 'package:flutter_app_saludable/core/auth/google_auth_service.dart';

/// Fake inyectable en [AuthProvider] para los tests de logout Google (AUTH-022)
/// y del cierre de teclado en el login con Google (UI-001).
class FakeGoogleAuthService extends GoogleAuthService {
  FakeGoogleAuthService({
    this.throwOnSignOut = false,
    this.idToken,
    this.onSignIn,
  });

  int signOutCalls = 0;
  bool throwOnSignOut;

  /// idToken que devuelve [signIn]. `null` simula que el usuario canceló.
  final String? idToken;

  /// Se ejecuta dentro de [signIn], en el momento en que el selector nativo de
  /// cuentas estaría en pantalla. Permite observar el estado del teclado justo
  /// ahí, que es donde se manifiesta UI-001.
  final Future<void> Function()? onSignIn;

  int signInCalls = 0;

  @override
  Future<String?> signIn() async {
    signInCalls++;
    // Imita el salto a la activity nativa: cede un turno del event loop para
    // que el framework procese el unfocus antes de leer el estado.
    await Future<void>.delayed(Duration.zero);
    await onSignIn?.call();
    return idToken;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (throwOnSignOut) {
      throw StateError('Google signOut failed');
    }
  }
}
