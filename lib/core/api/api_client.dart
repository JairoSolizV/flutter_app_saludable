import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_saludable/core/api/public_api_paths.dart';
import 'package:flutter_app_saludable/core/auth/session_expiration_handler.dart';
import 'package:flutter_app_saludable/core/auth/token_store.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';

class ApiClient {
  final Dio _dio;
  final TokenStore _tokenStore;
  final SessionExpirationHandler? _sessionExpirationHandler;

  ApiClient(
    this._tokenStore, {
    SessionExpirationHandler? sessionExpirationHandler,
    Dio? dio,
  })  : _sessionExpirationHandler = sessionExpirationHandler,
        _dio = dio ??
            Dio(BaseOptions(
              // URL de Producción
              baseUrl: 'https://clubs-api.onrender.com/api',
              // baseUrl: 'http://10.0.2.2:8080/api', // Local emulador
              connectTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Classification siempre desde el path (extra del caller no fuerza público).
        final isPublic = PublicApiPaths.isPublic(options.path);
        options.extra[kRequestIsPublic] = isPublic;

        final existingAuth = _authorizationHeaderValue(options.headers);
        final hasManualAuth =
            existingAuth != null && existingAuth.trim().isNotEmpty;

        if (isPublic) {
          options.extra[kRequestHadAuthorization] = hasManualAuth;
          if (kDebugMode) {
            logDebug('REQUEST[${options.method}] => PATH: ${options.path}');
          }
          return handler.next(options);
        }

        // Durante invalidación 401 no adjuntar JWT.
        if (_sessionExpirationHandler?.isInvalidating == true) {
          options.extra[kRequestHadAuthorization] = hasManualAuth;
          if (kDebugMode) {
            logDebug(
              '[DEBUG API_CLIENT] Sesión invalidándose; sin Authorization en ${options.path}',
            );
          }
          return handler.next(options);
        }

        var hadAuthorization = hasManualAuth;

        if (_tokenStore.isInitialized) {
          final token = _tokenStore.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            hadAuthorization = true;
            if (kDebugMode) {
              logDebug(
                '[DEBUG API_CLIENT] Authorization adjunto para ${options.path}',
              );
            }
          } else if (kDebugMode) {
            logDebug(
              '[DEBUG API_CLIENT] Sin token en memoria para ${options.path}',
            );
          }
        } else if (kDebugMode) {
          logDebug(
            '[DEBUG API_CLIENT] TokenStore no inicializado en ${options.path}',
          );
        }

        options.extra[kRequestHadAuthorization] = hadAuthorization;

        if (kDebugMode) {
          logDebug('REQUEST[${options.method}] => PATH: ${options.path}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          logDebug(
            'RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}',
          );
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        final status = e.response?.statusCode;
        if (kDebugMode) {
          logDebug(
            'ERROR[$status] => PATH: ${e.requestOptions.path}',
          );
        }

        if (status == 401) {
          final extras = e.requestOptions.extra;
          final hadAuthorization = extras[kRequestHadAuthorization] == true;
          // Re-evaluar path: el caller no puede forzar público vía extra.
          final isPublic = PublicApiPaths.isPublic(e.requestOptions.path);

          if (hadAuthorization && !isPublic) {
            if (kDebugMode) {
              logDebug(
                '[DEBUG API_CLIENT] 401 autenticado → invalidar sesión',
              );
            }
            e.requestOptions.extra[kRequestSessionExpiredHandled] = true;
            final handler401 = _sessionExpirationHandler;
            if (handler401 != null) {
              try {
                await handler401.handleUnauthorized();
              } catch (_) {
                logDebug(
                  '[DEBUG API_CLIENT] SessionExpirationHandler falló',
                );
              }
            }
          } else if (kDebugMode) {
            logDebug(
              '[DEBUG API_CLIENT] 401 en endpoint público o sin JWT; sin logout',
            );
          }
        }

        return handler.next(e);
      },
    ));
  }

  Dio get client => _dio;

  /// Expuesto solo para tests de composición DI.
  @visibleForTesting
  TokenStore get tokenStoreForTest => _tokenStore;

  @visibleForTesting
  SessionExpirationHandler? get sessionHandlerForTest =>
      _sessionExpirationHandler;

  static String? _authorizationHeaderValue(Map<String, dynamic> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        final value = entry.value;
        if (value == null) return null;
        return value.toString();
      }
    }
    return null;
  }
}
