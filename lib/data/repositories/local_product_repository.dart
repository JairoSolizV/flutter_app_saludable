import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/remote/product_remote_data_source.dart';

class LocalProductRepository implements ProductRepository {
  final DatabaseHelper _dbHelper;
  final ProductRemoteDataSource? _remoteDataSource; // Opcional para mantener compatibilidad si no se inyecta

  LocalProductRepository(this._dbHelper, {ProductRemoteDataSource? remoteDataSource}) 
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<Product>> getProducts({required int hubId, required int clubId}) async {
    // 1. Intentar obtener de API si hay remoteDataSource
    if (_remoteDataSource != null) {
      try {
        final remoteProducts = await _remoteDataSource!.getProducts(hubId: hubId, clubId: clubId);
        
        // Solo guardamos en caché si es una carga general (sin filtro de club) o lógica futura
        // Por simplicidad, guardamos todo lo que llega
        await _saveProductsToLocal(remoteProducts);
        
        return remoteProducts;
      } catch (e) {
        print('Error fetching remote products: $e. Falling back to local DB.');
        // Fallback a local si falla red
      }
    }
    
    // 3. Leer de BD Local
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products');

    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }

  Future<void> _saveProductsToLocal(List<Product> products) async {
    final db = await _dbHelper.database;
    // Usamos batch para performance
    final batch = db.batch();
    // Opcional: Limpiar tabla antes o usar upsert logic. 
    // Aquí haremos replace.
    for (var product in products) {
      batch.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Product?> getProductById(String id) async {
    final db = await _dbHelper.database;
    final result = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return Product.fromMap(result.first);
    }
    return null;
  }

  @override
  @override
  Future<void> createProduct(Product product, int clubId) async {
    if (_remoteDataSource != null) {
        // Asumimos que _remoteDataSource es ProductRemoteDataSourceImpl
        await (_remoteDataSource as dynamic).createProduct(product, clubId); 
    }
  }

  @override
  Future<void> updateProduct(Product product) async {
    if (_remoteDataSource != null) {
      await (_remoteDataSource as dynamic).updateProduct(product);
    }
    // Update local cache
    final db = await _dbHelper.database;
    await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  @override
  Future<void> deleteProduct(String id) async {
    if (_remoteDataSource != null) {
      await (_remoteDataSource as dynamic).deleteProduct(id);
    }
    // Delete from local cache
    final db = await _dbHelper.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {
    if (_remoteDataSource != null) {
      await (_remoteDataSource as dynamic).toggleProductAvailability(clubId, productId);
    }
  }
}
