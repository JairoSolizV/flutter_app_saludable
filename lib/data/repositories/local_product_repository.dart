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
  Future<List<Product>> getProducts() async {
    // 1. Intentar obtener de API si hay remoteDataSource
    if (_remoteDataSource != null) {
      try {
        final remoteProducts = await _remoteDataSource!.getProducts();
        // 2. Guardar en BD Local (Cache)
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
}
