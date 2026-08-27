import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app_saludable/core/api/api_client.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_expiration_handler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_secure_storage_gateway.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  int fetchCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount++;
    lastOptions = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ApiClient + TokenStore', () {
    late InMemorySecureStorageGateway storage;
    late SecureTokenStore tokenStore;
    late _RecordingAdapter adapter;
    late ApiClient apiClient;

    setUp(() async {
      storage = InMemorySecureStorageGateway();
      tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
      adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.httpClientAdapter = adapter;
      apiClient = ApiClient(
        tokenStore,
        sessionExpirationHandler:
            SessionExpirationHandler(tokenStore: tokenStore),
        dio: dio,
      );
    });

    test('usa el token de memoria en Authorization', () async {
      await tokenStore.saveToken('fake-jwt-for-tests');
      final readsBefore = storage.readCount;

      await apiClient.client.get('/clubes');

      expect(adapter.fetchCount, 1);
      expect(
        adapter.lastOptions!.headers['Authorization'],
        'Bearer fake-jwt-for-tests',
      );
      // No relee secure storage por request.
      expect(storage.readCount, readsBefore);
    });

    test('no añade Authorization sin token', () async {
      await apiClient.client.get('/clubes');

      expect(
          adapter.lastOptions!.headers.containsKey('Authorization'), isFalse);
    });

    test('no consulta almacenamiento en cada request', () async {
      await tokenStore.saveToken('memory-only-token');
      final readsAfterSave = storage.readCount;

      await apiClient.client.get('/a');
      await apiClient.client.get('/b');
      await apiClient.client.get('/c');

      expect(storage.readCount, readsAfterSave);
      expect(adapter.fetchCount, 3);
    });

    test('omite Authorization en endpoints públicos', () async {
      await tokenStore.saveToken('fake-jwt-for-tests');

      await apiClient.client.post('/auth/login', data: {});
      expect(
          adapter.lastOptions!.headers.containsKey('Authorization'), isFalse);

      await apiClient.client.post('/auth/google', data: {'idToken': 'x'});
      expect(
          adapter.lastOptions!.headers.containsKey('Authorization'), isFalse);

      await apiClient.client.get('/public/clubes');
      expect(
          adapter.lastOptions!.headers.containsKey('Authorization'), isFalse);
    });
  });
}
