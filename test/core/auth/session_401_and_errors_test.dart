import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/api/api_client.dart';
import 'package:flutter_app_saludable/core/api/public_api_paths.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_expiration_handler.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import 'package:flutter_app_saludable/core/ui/session_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_secure_storage_gateway.dart';

/// Adapter que retiene todas las respuestas hasta liberar una barrera.
class _BarrierAdapter implements HttpClientAdapter {
  _BarrierAdapter();

  int statusCode = 401;
  String body = '{}';
  final List<Completer<void>> _ready = [];
  Completer<void>? _release;
  int fetchCount = 0;
  RequestOptions? lastOptions;
  final List<RequestOptions> allOptions = [];

  void armBarrier({required int expected}) {
    _ready.clear();
    _release = Completer<void>();
    for (var i = 0; i < expected; i++) {
      _ready.add(Completer<void>());
    }
  }

  Future<void> waitUntilAllArrived() =>
      Future.wait(_ready.map((c) => c.future));

  void releaseAll() {
    final r = _release;
    if (r != null && !r.isCompleted) r.complete();
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount++;
    lastOptions = options;
    allOptions.add(options);

    final idx = fetchCount - 1;
    if (_release != null && idx < _ready.length) {
      if (!_ready[idx].isCompleted) _ready[idx].complete();
      await _release!.future;
    }

    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DioException _dioHttp({
  required RequestOptions request,
  required int status,
  dynamic data,
  Map<String, dynamic>? extra,
}) {
  final opts = request;
  if (extra != null) {
    opts.extra.addAll(extra);
  }
  return DioException(
    requestOptions: opts,
    response: Response(
      requestOptions: opts,
      statusCode: status,
      data: data,
    ),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  const fakeJwt = 'fake.jwt.token.value';

  group('PublicApiPaths (estricto)', () {
    test('matriz de rutas públicas/protegidas', () {
      expect(PublicApiPaths.isPublic('/auth/login'), isTrue);
      expect(PublicApiPaths.isPublic('/auth/login/'), isTrue);
      expect(PublicApiPaths.isPublic('/auth/login?x=1'), isTrue);
      expect(PublicApiPaths.isPublic('/api/auth/login'), isTrue);
      expect(PublicApiPaths.isPublic('/auth/register'), isTrue);
      expect(PublicApiPaths.isPublic('/auth/register-basico'), isTrue);
      expect(PublicApiPaths.isPublic('/auth/check-email'), isTrue);
      expect(PublicApiPaths.isPublic('/auth/verify-email'), isTrue);
      expect(PublicApiPaths.isPublic('/auth/resend-code'), isTrue);
      expect(PublicApiPaths.isPublic('/auth/forgot-password'), isTrue);
      expect(PublicApiPaths.isPublic('/auth/verify-reset-code'), isTrue);
      expect(PublicApiPaths.isPublic('/auth/reset-password'), isTrue);
      expect(PublicApiPaths.isPublic('/auth/google'), isTrue);
      expect(
        PublicApiPaths.isPublic(
          'https://clubs-api.onrender.com/api/auth/login',
        ),
        isTrue,
      );
      expect(
        PublicApiPaths.isPublic(
          'https://clubs-api.onrender.com/api/auth/google',
        ),
        isTrue,
      );
      expect(PublicApiPaths.isPublic('/auth/me'), isFalse);
      expect(PublicApiPaths.isPublic('/clubes/1/auth/login'), isFalse);
      expect(PublicApiPaths.isPublic('/auth/login-malicioso'), isFalse);
      expect(PublicApiPaths.isPublic('/public/clubes'), isTrue);
      expect(PublicApiPaths.isPublic('/api/public/clubes'), isTrue);
      expect(PublicApiPaths.isPublic('/publicidad'), isFalse);
      expect(PublicApiPaths.isPublic('/clubes/public/1'), isFalse);
    });
  });

  group('ApiClient 401 + Authorization', () {
    late InMemorySecureStorageGateway storage;
    late SecureTokenStore tokenStore;
    late SessionExpirationHandler sessionHandler;
    late _BarrierAdapter adapter;
    late ApiClient apiClient;
    late int clearCalls;
    late int uiCalls;

    setUp(() async {
      storage = InMemorySecureStorageGateway();
      tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
      sessionHandler = SessionExpirationHandler(tokenStore: tokenStore);
      clearCalls = 0;
      uiCalls = 0;
      sessionHandler.bind(
        clearLocalSession: () async {
          clearCalls++;
        },
        onSessionExpiredUi: () async {
          uiCalls++;
        },
      );
      adapter = _BarrierAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.httpClientAdapter = adapter;
      apiClient = ApiClient(
        tokenStore,
        sessionExpirationHandler: sessionHandler,
        dio: dio,
      );
    });

    test('request autenticada añade Authorization', () async {
      await tokenStore.saveToken(fakeJwt);
      adapter.statusCode = 200;
      await apiClient.client.get('/clubes');
      expect(
        adapter.lastOptions!.headers['Authorization'],
        'Bearer $fakeJwt',
      );
      expect(adapter.lastOptions!.extra[kRequestHadAuthorization], isTrue);
    });

    test('Authorization manual se detecta sin exponer valor en extras',
        () async {
      adapter.statusCode = 200;
      await apiClient.client.get(
        '/clubes',
        options: Options(headers: {'Authorization': 'Bearer secret-manual'}),
      );
      expect(adapter.lastOptions!.extra[kRequestHadAuthorization], isTrue);
      // No hay key que copie el valor del token a extra.
      expect(
        adapter.lastOptions!.extra.values
            .any((v) => v == 'Bearer secret-manual'),
        isFalse,
      );
    });

    test('endpoint público no añade Authorization', () async {
      await tokenStore.saveToken(fakeJwt);
      adapter.statusCode = 200;
      await apiClient.client.post('/auth/login', data: {});
      expect(
          adapter.lastOptions!.headers.containsKey('Authorization'), isFalse);
      expect(adapter.lastOptions!.extra[kRequestIsPublic], isTrue);

      await apiClient.client.post('/auth/google', data: {'idToken': 'x'});
      expect(
          adapter.lastOptions!.headers.containsKey('Authorization'), isFalse);
      expect(adapter.lastOptions!.extra[kRequestIsPublic], isTrue);

      for (final path in [
        '/auth/forgot-password',
        '/auth/verify-reset-code',
        '/auth/reset-password',
      ]) {
        await apiClient.client.post(path, data: {});
        expect(
            adapter.lastOptions!.headers.containsKey('Authorization'), isFalse);
        expect(adapter.lastOptions!.extra[kRequestIsPublic], isTrue);
      }
    });

    test('endpoint protegido sí lleva Authorization con token en store',
        () async {
      await tokenStore.saveToken(fakeJwt);
      adapter.statusCode = 200;
      await apiClient.client.get('/clubes');
      expect(
        adapter.lastOptions!.headers['Authorization'],
        'Bearer $fakeJwt',
      );
      expect(adapter.lastOptions!.extra[kRequestIsPublic], isFalse);
    });

    test('extra no puede forzar ruta protegida como pública', () async {
      await tokenStore.saveToken(fakeJwt);
      adapter.statusCode = 401;
      try {
        await apiClient.client.get(
          '/pedidos/club/1',
          options: Options(extra: {kRequestIsPublic: true}),
        );
      } catch (_) {}
      expect(clearCalls, 1);
    });

    test('401 de /auth/login no ejecuta logout global', () async {
      adapter.statusCode = 401;
      adapter.body = '{"success":false,"message":"Credenciales incorrectas"}';
      try {
        await apiClient.client.post('/auth/login', data: {'email': 'a'});
      } catch (_) {}
      expect(clearCalls, 0);
      expect(uiCalls, 0);
      expect(tokenStore.getToken(), isNull);
    });

    test('401 de /auth/me sí ejecuta invalidación', () async {
      await tokenStore.saveToken(fakeJwt);
      adapter.statusCode = 401;
      try {
        await apiClient.client.get('/auth/me');
      } catch (_) {}
      expect(clearCalls, 1);
      expect(uiCalls, 1);
      expect(tokenStore.getToken(), isNull);
    });

    test('401 de endpoint protegido limpia sesión', () async {
      await tokenStore.saveToken(fakeJwt);
      adapter.statusCode = 401;
      try {
        await apiClient.client.get('/pedidos/club/1');
      } catch (_) {}
      expect(clearCalls, 1);
      expect(sessionHandler.logoutInvocationsForTest, 1);
      expect(tokenStore.getToken(), isNull);
    });

    test('dos 401 concurrentes con barrera ejecutan logout una sola vez',
        () async {
      await tokenStore.saveToken(fakeJwt);
      adapter.statusCode = 401;
      adapter.armBarrier(expected: 2);

      final futures = [
        apiClient.client.get('/a').then((_) {}, onError: (_) {}),
        apiClient.client.get('/b').then((_) {}, onError: (_) {}),
      ];

      await adapter.waitUntilAllArrived();
      adapter.releaseAll();
      await Future.wait(futures);

      expect(sessionHandler.logoutInvocationsForTest, 1);
      expect(clearCalls, 1);
      expect(uiCalls, 1);
    });

    test('cinco 401 concurrentes con barrera ejecutan logout una sola vez',
        () async {
      await tokenStore.saveToken(fakeJwt);
      adapter.statusCode = 401;
      adapter.armBarrier(expected: 5);

      final futures = List.generate(
        5,
        (i) => apiClient.client.get('/x$i').then((_) {}, onError: (_) {}),
      );

      await adapter.waitUntilAllArrived();
      adapter.releaseAll();
      await Future.wait(futures);

      expect(sessionHandler.logoutInvocationsForTest, 1);
      expect(uiCalls, 1);
    });

    test('después del logout, nuevas requests no llevan Authorization',
        () async {
      await tokenStore.saveToken(fakeJwt);
      adapter.statusCode = 401;
      try {
        await apiClient.client.get('/pedidos/club/1');
      } catch (_) {}

      adapter.statusCode = 200;
      await apiClient.client.get('/clubes');
      expect(
          adapter.lastOptions!.headers.containsKey('Authorization'), isFalse);
    });

    test('callback UI async puede fallar sin dejar inFlight bloqueado',
        () async {
      sessionHandler.bind(
        clearLocalSession: () async {
          clearCalls++;
        },
        onSessionExpiredUi: () async {
          uiCalls++;
          throw StateError('ui boom');
        },
      );
      await tokenStore.saveToken(fakeJwt);
      adapter.statusCode = 401;
      try {
        await apiClient.client.get('/auth/me');
      } catch (_) {}
      expect(clearCalls, 1);
      expect(tokenStore.getToken(), isNull);
      expect(sessionHandler.isInvalidating, isTrue); // latch
      // Un segundo 401 no vuelve a invocar logout.
      try {
        await apiClient.client.get('/auth/me');
      } catch (_) {}
      expect(sessionHandler.logoutInvocationsForTest, 1);
    });

    test('401 tardío tras logout manual no navega ni limpia de nuevo',
        () async {
      await tokenStore.saveToken(fakeJwt);
      sessionHandler.markLoggedOut();
      adapter.statusCode = 401;
      try {
        await apiClient.client.get('/pedidos/club/1');
      } catch (_) {}
      expect(clearCalls, 0);
      expect(uiCalls, 0);
    });

    test('403 no cierra sesión', () async {
      await tokenStore.saveToken(fakeJwt);
      adapter.statusCode = 403;
      adapter.body = '{"message":"Sin permisos"}';
      try {
        await apiClient.client.get('/pedidos/club/1');
      } catch (_) {}
      expect(clearCalls, 0);
      expect(tokenStore.getToken(), fakeJwt);
    });
  });

  group('SessionFeedback gate', () {
    test('messenger null no consume el gate', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      SessionFeedback.resetExpiredMessageGate();
      // Sin MaterialApp conectado a la key: currentState es null.
      SessionFeedback.showSessionExpiredMessage();
      expect(SessionFeedback.expiredMessageShownForTest, isFalse);
    });
  });

  group('ErrorMapper', () {
    RequestOptions req({Map<String, dynamic>? extra}) {
      final o = RequestOptions(path: '/x');
      if (extra != null) o.extra.addAll(extra);
      return o;
    }

    test('400 → ValidationException', () {
      final e = _dioHttp(
        request: req(),
        status: 400,
        data: {'success': false, 'message': 'Campo inválido'},
      );
      final mapped = ErrorMapper.fromDio(e);
      expect(mapped, isA<ValidationException>());
      expect(mapped.message, 'Campo inválido');
    });

    test('401 manejado globalmente → SessionExpiredException', () {
      final mapped = ErrorMapper.fromDio(
        _dioHttp(
          request: req(extra: {kRequestSessionExpiredHandled: true}),
          status: 401,
          data: {'message': 'JWT expired'},
        ),
      );
      expect(mapped, isA<SessionExpiredException>());
      expect(mapped.handledGlobally, isTrue);
      expect(shouldPresentErrorToUser(mapped), isFalse);
    });

    test('401 login no global → UnauthorizedException presentable', () {
      final mapped = ErrorMapper.fromDio(
        _dioHttp(
          request: req(),
          status: 401,
          data: {'message': 'Credenciales incorrectas'},
        ),
      );
      expect(mapped, isA<UnauthorizedException>());
      expect(mapped.handledGlobally, isFalse);
      expect(shouldPresentErrorToUser(mapped), isTrue);
    });

    test('trunca mensajes largos', () {
      final long = 'x' * 500;
      final mapped = ErrorMapper.fromDio(
        _dioHttp(request: req(), status: 400, data: {'message': long}),
      );
      expect(mapped.message.length, lessThanOrEqualTo(280));
    });

    test('HTML no se muestra directamente', () {
      final mapped = ErrorMapper.fromDio(
        _dioHttp(
          request: req(),
          status: 502,
          data: '<!DOCTYPE html><html><body>Bad Gateway</body></html>',
        ),
      );
      expect(mapped.message.contains('<'), isFalse);
    });

    test('no reenvuelve AppException', () {
      final original = ForbiddenException('Sin permiso');
      expect(ErrorMapper.fromObject(original), same(original));
    });

    test('403 → ForbiddenException', () {
      final mapped = ErrorMapper.fromDio(
        _dioHttp(
          request: req(),
          status: 403,
          data: {'message': 'Sin permisos'},
        ),
      );
      expect(mapped, isA<ForbiddenException>());
      expect(shouldPresentErrorToUser(mapped), isTrue);
    });

    test('404 se normaliza', () {
      final mapped = ErrorMapper.fromDio(
        _dioHttp(request: req(), status: 404, data: null),
      );
      expect(mapped, isA<NotFoundException>());
    });

    test('409 conserva mensaje funcional', () {
      final mapped = ErrorMapper.fromDio(
        _dioHttp(
          request: req(),
          status: 409,
          data: {'message': 'Ya existe una asistencia registrada para hoy.'},
        ),
      );
      expect(mapped, isA<ConflictException>());
      expect(mapped.message.contains('asistencia'), isTrue);
    });

    test('500 error de servidor genérico', () {
      final mapped = ErrorMapper.fromDio(
        _dioHttp(request: req(), status: 500, data: '<html>error</html>'),
      );
      expect(mapped, isA<ServerException>());
      expect(mapped.message.contains('<html>'), isFalse);
    });

    test('timeout → TimeoutException', () {
      final mapped = ErrorMapper.fromDio(
        DioException(
          requestOptions: req(),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      expect(mapped, isA<TimeoutException>());
    });

    test('no usa Map.toString como mensaje', () {
      final mapped = ErrorMapper.fromDio(
        _dioHttp(
          request: req(),
          status: 400,
          data: {
            'nested': {'a': 1},
          },
        ),
      );
      expect(mapped.message.contains('{'), isFalse);
    });
  });

  group('SessionExpirationHandler bind/unbind', () {
    test('unbind con generación vieja no limpia binding nuevo', () async {
      final storage = InMemorySecureStorageGateway();
      final tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
      final handler = SessionExpirationHandler(tokenStore: tokenStore);

      var callsOld = 0;
      var callsNew = 0;
      final oldGen = handler.bind(
        clearLocalSession: () async {
          callsOld++;
        },
        onSessionExpiredUi: () async {},
      );
      final newGen = handler.bind(
        clearLocalSession: () async {
          callsNew++;
        },
        onSessionExpiredUi: () async {},
      );
      expect(oldGen, isNot(newGen));
      handler.unbind(oldGen);

      await tokenStore.saveToken(fakeJwt);
      await handler.handleUnauthorized();
      expect(callsOld, 0);
      expect(callsNew, 1);
    });

    test('unbind elimina callbacks vigentes', () async {
      final storage = InMemorySecureStorageGateway();
      final tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
      final handler = SessionExpirationHandler(tokenStore: tokenStore);
      var calls = 0;
      final gen = handler.bind(
        clearLocalSession: () async {
          calls++;
        },
        onSessionExpiredUi: () async {},
      );
      handler.unbind(gen);
      await tokenStore.saveToken(fakeJwt);
      await handler.handleUnauthorized();
      expect(calls, 0);
      expect(tokenStore.getToken(), isNull);
    });
  });

  group('navegación pública', () {
    test('navegación pública detecta login/guest', () {
      expect(isPublicNavigationLocation('/login'), isTrue);
      expect(isPublicNavigationLocation('/guest-home'), isTrue);
      expect(isPublicNavigationLocation('/host-dashboard'), isFalse);
    });
  });
}
