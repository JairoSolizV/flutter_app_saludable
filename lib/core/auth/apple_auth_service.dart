import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Credenciales nativas de Apple listas para enviar al backend.
///
/// Contrato Flutter → `POST /api/auth/apple` (espejo de `/auth/google`):
/// - [identityToken]: JWT de Apple (obligatorio)
/// - [authorizationCode]: código de un solo uso (opcional; recomendado para revoke)
/// - [nonce]: nonce **crudo** (el hash SHA-256 se envió a Apple)
/// - [givenName] / [familyName]: solo en la primera autorización (opcionales)
///
/// Nunca registrar estos valores en logs.
class AppleAuthCredentials {
  final String identityToken;
  final String? authorizationCode;
  final String nonce;
  final String? givenName;
  final String? familyName;

  const AppleAuthCredentials({
    required this.identityToken,
    required this.nonce,
    this.authorizationCode,
    this.givenName,
    this.familyName,
  });
}

/// Flujo nativo Sign in with Apple (iOS / macOS).
///
/// Genera nonce anti-replay, solicita email + nombre en scopes, y no vuelve a
/// exigir nombre/email si Apple no los entrega en autorizaciones posteriores.
class AppleAuthService {
  /// Inicia Sign in with Apple.
  ///
  /// Retorna `null` si el usuario cancela.
  /// Lanza [ValidationException] u [AppException] ante errores de Apple.
  Future<AppleAuthCredentials?> signIn() async {
    if (kIsWeb) {
      throw ValidationException(
        'Iniciar sesión con Apple no está disponible en esta plataforma.',
      );
    }

    final rawNonce = generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final identityToken = credential.identityToken?.trim();
      final authorizationCode = credential.authorizationCode.trim();

      if (identityToken == null || identityToken.isEmpty) {
        logDebug(
          '[AppleAuthService] Credencial sin identityToken (misconfiguración)',
        );
        throw ValidationException(
          'No se pudo obtener el token de autenticación de Apple.',
        );
      }
      if (authorizationCode.isEmpty) {
        logDebug(
          '[AppleAuthService] Credencial sin authorizationCode; se omite en body',
        );
      }

      final given = credential.givenName?.trim();
      final family = credential.familyName?.trim();

      logDebug(
        '[AppleAuthService] Autorización Apple completada en dispositivo',
      );

      return AppleAuthCredentials(
        identityToken: identityToken,
        authorizationCode:
            authorizationCode.isEmpty ? null : authorizationCode,
        nonce: rawNonce,
        givenName: (given != null && given.isNotEmpty) ? given : null,
        familyName: (family != null && family.isNotEmpty) ? family : null,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        logDebug('[AppleAuthService] Usuario canceló Sign in with Apple');
        return null;
      }
      logDebug('[AppleAuthService] Error de autorización Apple: ${e.code}');
      throw ValidationException(
        _messageForAppleCode(e.code),
        code: e.code.name,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      logDebug('[AppleAuthService] Error inesperado en Sign in with Apple');
      throw ValidationException(
        'Error al iniciar sesión con Apple. Intenta de nuevo.',
      );
    }
  }

  /// Sign in with Apple no mantiene una sesión SDK local como Google;
  /// el logout de la app limpia JWT/perfil propio. La revocación ante Apple
  /// ocurre en el servidor al eliminar la cuenta (no al cerrar sesión).
  Future<void> signOut() async {}

  static String _messageForAppleCode(AuthorizationErrorCode code) {
    switch (code) {
      case AuthorizationErrorCode.canceled:
        return 'Inicio de sesión cancelado.';
      case AuthorizationErrorCode.failed:
        return 'No se pudo completar el inicio de sesión con Apple.';
      case AuthorizationErrorCode.invalidResponse:
        return 'Respuesta inválida de Apple. Intenta de nuevo.';
      case AuthorizationErrorCode.notHandled:
        return 'Apple no pudo procesar la solicitud.';
      case AuthorizationErrorCode.notInteractive:
        return 'Se requiere interacción del usuario para continuar.';
      case AuthorizationErrorCode.unknown:
      case AuthorizationErrorCode.credentialExport:
      case AuthorizationErrorCode.credentialImport:
      case AuthorizationErrorCode.matchedExcludedCredential:
        return 'Error desconocido al iniciar sesión con Apple.';
    }
  }
}
