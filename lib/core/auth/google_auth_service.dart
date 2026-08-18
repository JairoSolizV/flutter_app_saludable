import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn;

  GoogleAuthService({String? webClientId})
      : _googleSignIn = GoogleSignIn(
          // Si el backend requiere un idToken para validación, a veces es necesario 
          // pasar el clientId de la aplicación WEB (no el de Android) en serverClientId.
          // Por defecto en Android tomará el SHA-1 automático.
          serverClientId: webClientId,
          scopes: [
            'email',
            'profile',
          ],
        );

  /// Inicia el flujo de autenticación de Google y retorna el ID Token
  Future<String?> signIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // El usuario canceló el login
        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      
      logDebug('[GoogleAuthService] Login exitoso. Email: ${account.email}');
      return idToken;
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
