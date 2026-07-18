import 'package:flutter_app_saludable/core/auth/secure_storage_exception.dart';
import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_token_migrator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_repository.dart';
import 'in_memory_secure_storage_gateway.dart';

void main() {
  const fakeJwt = 'fake.jwt.token.value';
  const otherJwt = 'other.secure.token.value';

  group('SecureTokenStore', () {
    test('inicialización sin token', () async {
      final storage = InMemorySecureStorageGateway();
      final store = SecureTokenStore(storage: storage);

      await store.initialize();

      expect(store.isInitialized, isTrue);
      expect(store.getToken(), isNull);
      expect(storage.readCount, 1);
    });

    test('inicialización con token seguro', () async {
      final storage = InMemorySecureStorageGateway()
        ..seed(kNutrilifeJwtStorageKey, fakeJwt);
      final store = SecureTokenStore(storage: storage);

      await store.initialize();

      expect(store.getToken(), fakeJwt);
    });

    test('saveToken actualiza persistencia y memoria', () async {
      final storage = InMemorySecureStorageGateway();
      final store = SecureTokenStore(storage: storage);
      await store.initialize();

      await store.saveToken(fakeJwt);

      expect(store.getToken(), fakeJwt);
      expect(storage.containsKey(kNutrilifeJwtStorageKey), isTrue);
      expect(storage.writeCount, 1);
    });

    test('clearToken elimina persistencia y memoria', () async {
      final storage = InMemorySecureStorageGateway()
        ..seed(kNutrilifeJwtStorageKey, fakeJwt);
      final store = SecureTokenStore(storage: storage);
      await store.initialize();

      await store.clearToken();

      expect(store.getToken(), isNull);
      expect(storage.containsKey(kNutrilifeJwtStorageKey), isFalse);
    });

    test('initialize duplicado no relee almacenamiento', () async {
      final storage = InMemorySecureStorageGateway();
      final store = SecureTokenStore(storage: storage);

      await store.initialize();
      await store.initialize();

      expect(storage.readCount, 1);
    });

    test('fallo de lectura lanza SecureStorageException', () async {
      final storage = InMemorySecureStorageGateway()..failReads = true;
      final store = SecureTokenStore(storage: storage);

      expect(
        () => store.initialize(),
        throwsA(isA<SecureStorageException>()),
      );
      expect(store.isInitialized, isFalse);
    });
  });

  group('SessionTokenMigrator', () {
    test('migra SQLite → secure storage y limpia legacy', () async {
      final storage = InMemorySecureStorageGateway();
      final store = SecureTokenStore(storage: storage);
      await store.initialize();
      final users = FakeUserRepository()..legacyToken = fakeJwt;
      final migrator = SessionTokenMigrator(
        tokenStore: store,
        userRepository: users,
      );

      await migrator.migrateIfNeeded();

      expect(store.getToken(), fakeJwt);
      expect(users.legacyToken, isNull);
      expect(users.clearPersistedTokenCalls, 1);
      expect(users.readLegacyTokenCalls, 1);
    });

    test('no sobrescribe un token seguro existente', () async {
      final storage = InMemorySecureStorageGateway()
        ..seed(kNutrilifeJwtStorageKey, otherJwt);
      final store = SecureTokenStore(storage: storage);
      await store.initialize();
      final users = FakeUserRepository()..legacyToken = fakeJwt;
      final migrator = SessionTokenMigrator(
        tokenStore: store,
        userRepository: users,
      );

      await migrator.migrateIfNeeded();

      expect(store.getToken(), otherJwt);
      expect(users.readLegacyTokenCalls, 0);
      expect(users.clearPersistedTokenCalls, 1);
      expect(users.legacyToken, isNull);
    });

    test('no borra SQLite si falla secure storage', () async {
      final storage = InMemorySecureStorageGateway();
      final store = SecureTokenStore(storage: storage);
      await store.initialize();
      storage.failWrites = true;
      final users = FakeUserRepository()..legacyToken = fakeJwt;
      final migrator = SessionTokenMigrator(
        tokenStore: store,
        userRepository: users,
      );

      await expectLater(
        migrator.migrateIfNeeded(),
        throwsA(isA<SecureStorageException>()),
      );

      expect(users.legacyToken, fakeJwt);
      expect(users.clearPersistedTokenCalls, 0);
      expect(store.getToken(), isNull);
    });

    test('migración ejecutada dos veces es idempotente', () async {
      final storage = InMemorySecureStorageGateway();
      final store = SecureTokenStore(storage: storage);
      await store.initialize();
      final users = FakeUserRepository()..legacyToken = fakeJwt;
      final migrator = SessionTokenMigrator(
        tokenStore: store,
        userRepository: users,
      );

      await migrator.migrateIfNeeded();
      await migrator.migrateIfNeeded();

      expect(store.getToken(), fakeJwt);
      expect(storage.writeCount, 1);
      expect(users.clearPersistedTokenCalls, 2);
    });
  });
}
