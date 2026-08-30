import 'dart:io';

import 'package:flutter_app_saludable/core/database/database_helper.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/data/repositories/local_product_repository.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/isolated_test_database.dart';

class _FakeProductRemoteDataSource implements ProductRemoteDataSource {
  List<Product> productsToReturn = [];
  List<Product> availableToReturn = [];
  Object? getProductsError;
  Object? getAvailableError;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int toggleCalls = 0;

  @override
  Future<List<Product>> getProducts(
      {required int hubId, required int clubId}) async {
    if (getProductsError != null) throw getProductsError!;
    return productsToReturn;
  }

  @override
  Future<List<Product>> getAvailableProductsByClub(int clubId) async {
    if (getAvailableError != null) throw getAvailableError!;
    return availableToReturn;
  }

  @override
  Future<void> createProduct(Product product, int clubId) async {
    createCalls++;
  }

  @override
  Future<String> uploadProductImage(File imageFile) async => '';

  @override
  Future<void> createProductProposal({
    required int hubId,
    required String nombre,
    required String descripcion,
    required String ingredientes,
    required int puntosValor,
    String? imagenUrl,
    List<ProductOptionGroup>? optionGroups,
  }) async {}

  @override
  Future<Product> updateProduct(Product product) async {
    updateCalls++;
    return product;
  }

  @override
  Future<Product> reenviarProducto(String productId) async {
    return Product(
      id: productId,
      name: '',
      description: '',
      tipo: 'LOCAL',
      estadoAprobacion: 'PENDIENTE',
    );
  }

  @override
  Future<void> deleteProduct(String id) async {
    deleteCalls++;
  }

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {
    toggleCalls++;
  }
}

void main() {
  late DatabaseHelper dbHelper;
  late _FakeProductRemoteDataSource remote;
  late LocalProductRepository repo;

  setUpAll(() async {
    dbHelper = await openIsolatedTestDatabase();
  });

  tearDownAll(() async {
    await closeIsolatedTestDatabase();
  });

  setUp(() async {
    final db = await dbHelper.database;
    await db.delete('products');
    remote = _FakeProductRemoteDataSource();
    repo = LocalProductRepository(dbHelper, remoteDataSource: remote);
  });

  tearDown(() async {
    final db = await dbHelper.database;
    await db.delete('products');
  });

  group('getProducts', () {
    test('éxito guarda copia local y devuelve productos remotos',
        async_(() async {
      remote.productsToReturn = [
        Product(id: '1', name: 'Batido', description: 'D', hubId: 7),
      ];

      final products = await repo.getProducts(hubId: 7, clubId: 1);

      expect(products, hasLength(1));
      final local = await repo.getProductById('1');
      expect(local, isNotNull);
      expect(local!.name, 'Batido');
    }));

    test('limpia productos antiguos del mismo hub antes de guardar',
        async_(() async {
      final db = await dbHelper.database;
      await db.insert(
        'products',
        Product(id: 'old', name: 'Viejo', description: '', hubId: 7).toMap(),
      );

      remote.productsToReturn = [
        Product(id: 'new', name: 'Nuevo', description: '', hubId: 7),
      ];
      await repo.getProducts(hubId: 7, clubId: 1);

      expect(await repo.getProductById('old'), isNull);
      expect(await repo.getProductById('new'), isNotNull);
    }));

    test('error remoto se propaga (rethrow) sin fallback local',
        async_(() async {
      remote.getProductsError = Exception('fallo de red');

      await expectLater(
        () => repo.getProducts(hubId: 1, clubId: 1),
        throwsException,
      );
    }));

    test('sin remoteDataSource devuelve lista vacía', async_(() async {
      final repoSinRemote = LocalProductRepository(dbHelper);
      final products = await repoSinRemote.getProducts(hubId: 1, clubId: 1);
      expect(products, isEmpty);
    }));
  });

  group('getAvailableProductsByClub', () {
    test('devuelve productos remotos sin cachear', async_(() async {
      remote.availableToReturn = [
        Product(id: '5', name: 'Disponible', description: ''),
      ];
      final products = await repo.getAvailableProductsByClub(3);
      expect(products, hasLength(1));
      expect(await repo.getProductById('5'), isNull);
    }));

    test('error remoto se propaga', async_(() async {
      remote.getAvailableError = Exception('fallo');
      await expectLater(
        () => repo.getAvailableProductsByClub(3),
        throwsException,
      );
    }));

    test('sin remoteDataSource devuelve lista vacía', async_(() async {
      final repoSinRemote = LocalProductRepository(dbHelper);
      final products = await repoSinRemote.getAvailableProductsByClub(3);
      expect(products, isEmpty);
    }));
  });

  group('getProductById', () {
    test('sin coincidencias devuelve null', async_(() async {
      expect(await repo.getProductById('inexistente'), isNull);
    }));
  });

  group('createProduct / updateProduct / deleteProduct / toggle', () {
    test('createProduct delega al remoto', async_(() async {
      await repo.createProduct(
        Product(id: '1', name: 'P', description: ''),
        1,
      );
      expect(remote.createCalls, 1);
    }));

    test('updateProduct actualiza remoto y caché local', async_(() async {
      final db = await dbHelper.database;
      await db.insert(
        'products',
        Product(id: '1', name: 'Viejo', description: '').toMap(),
      );

      await repo
          .updateProduct(Product(id: '1', name: 'Nuevo', description: ''));

      expect(remote.updateCalls, 1);
      final updated = await repo.getProductById('1');
      expect(updated!.name, 'Nuevo');
    }));

    test('deleteProduct no borra ni llama desactivar', async_(() async {
      final db = await dbHelper.database;
      await db.insert(
        'products',
        Product(id: '1', name: 'P', description: '').toMap(),
      );

      await expectLater(
        () => repo.deleteProduct('1'),
        throwsA(isA<UnsupportedError>()),
      );

      expect(remote.deleteCalls, 0);
      expect(await repo.getProductById('1'), isNotNull);
    }));

    test('toggleProductAvailability delega al remoto', async_(() async {
      await repo.toggleProductAvailability(1, '1');
      expect(remote.toggleCalls, 1);
    }));
  });
}

dynamic async_(Future<void> Function() body) => body;
