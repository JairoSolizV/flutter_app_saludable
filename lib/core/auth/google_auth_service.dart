import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';

/// Client ID de la app iOS (GIDClientID). No usar como audience del backend.
const String kGoogleIosClientId =
    '812612197014-up7cbqcmid5j7tb59jh8qtdf8l9mnkfe.apps.googleusercontent.com';

/// Web OAuth Client ID: audience del idToken que valida el backend.
/// Debe coincidir con GIDServerClientID en Info.plist.
const String kGoogleWebClientId =
    '812612197014-t4ud108qj177tpoh5in0qf6hiv1rqo4h.apps.googleusercontent.com';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn;

  GoogleAuthService({String? webClientId})
      : _googleSignIn = GoogleSignIn(
          clientId: kGoogleIosClientId,
          // serverClientId debe ser el Web Client ID para que Google
          // emita un idToken cuyo `aud` coincida con el backend.
          serverClientId: webClientId ?? kGoogleWebClientId,
          scopes: [
            'email',
            'profile',
          ],
        );

  /// Inicia el flujo de autenticación de Google y retorna el ID Token.
  ///
  /// Retorna `null` solo si el usuario cancela el selector de cuentas.
  /// Lanza si se eligió una cuenta pero no hay [idToken] (misconfiguración).
  Future<String?> signIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // El usuario canceló el login
        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        logDebug(
          '[GoogleAuthService] Cuenta seleccionada (${account.email}) sin idToken',
        );
        throw ValidationException(
          'No se pudo obtener el token de autenticación de Google.',
        );
      }

      logDebug('[GoogleAuthService] Login exitoso. Email: ${account.email}');
      return idToken;
    } on AppException {
      rethrow;
    } catch (e) {
      logDebug('[GoogleAuthService] Error durante Google Sign-In: $e');
      throw Exception('Error al iniciar sesión con Google: $e');
    }
  }

  /// Cierra sesión de Google localmente
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      logDebug('[GoogleAuthService] Error al cerrar sesión en Google: $e');
    }
  }
}
