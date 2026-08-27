/// Rutas públicas del API (coinciden con SecurityConfig del backend).
///
/// Fuente única: no duplicar esta lista en interceptores ni pantallas.
/// Las rutas son relativas al `baseUrl` (`…/api`).
///
/// Matching estricto:
/// - endpoints de auth: igualdad exacta tras normalizar;
/// - público por segmento: solo `/public` o `/public/...` (path segments).
class PublicApiPaths {
  PublicApiPaths._();

  static const List<String> exactAuthPaths = [
    '/auth/login',
    '/auth/register',
    '/auth/register-basico',
    '/auth/check-email',
    '/auth/verify-email',
    '/auth/resend-code',
    '/auth/forgot-password',
    '/auth/verify-reset-code',
    '/auth/reset-password',
    '/auth/google',
  ];

  /// True si [path] es un endpoint público (login, registro, `/public/**`, etc.).
  ///
  /// `/auth/me` **no** es público.
  /// Rutas como `/clubes/1/auth/login` o `/publicidad` **no** son públicas.
  static bool isPublic(String path) {
    final normalized = _normalize(path);
    if (_isPublicSegmentPath(normalized)) {
      return true;
    }
    return exactAuthPaths.contains(normalized);
  }

  /// Primer segmento == `public` (p. ej. `/public`, `/public/clubes`).
  /// No coincide con `/publicidad` ni `/clubes/public/1`.
  static bool _isPublicSegmentPath(String normalized) {
    if (normalized == '/public') return true;
    return normalized.startsWith('/public/');
  }

  /// Normaliza path de Dio / URIs absolutas a forma `/recurso/...` relativa a `/api`.
  static String _normalize(String path) {
    var p = path.trim();
    if (p.isEmpty) return '/';

    // Fragmento
    final hash = p.indexOf('#');
    if (hash >= 0) {
      p = p.substring(0, hash);
    }

    // Query
    final q = p.indexOf('?');
    if (q >= 0) {
      p = p.substring(0, q);
    }

    // URI absoluta → quedarse con path
    final schemeIdx = p.indexOf('://');
    if (schemeIdx >= 0) {
      final pathStart = p.indexOf('/', schemeIdx + 3);
      p = pathStart >= 0 ? p.substring(pathStart) : '/';
    }

    // Prefijo `/api` o `/api/`
    if (p == '/api') {
      p = '/';
    } else if (p.startsWith('/api/')) {
      p = p.substring(4); // deja "/auth/..."
    }

    if (!p.startsWith('/')) {
      p = '/$p';
    }

    // Colapsar slashes duplicados (salvo raíz)
    p = p.replaceAll(RegExp(r'/{2,}'), '/');

    if (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }

    return p;
  }
}

/// Keys en [RequestOptions.extra] para el interceptor.
const String kRequestHadAuthorization = 'hadAuthorization';
const String kRequestIsPublic = 'isPublic';

/// Metadata: el 401 de este request ya disparó invalidación global de sesión.
const String kRequestSessionExpiredHandled = 'sessionExpiredHandled';
