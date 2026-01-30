import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'nutrilife_club.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla Users
    await db.execute('''
      CREATE TABLE users(
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        role TEXT,
        token TEXT,
        phone TEXT,
        photo_url TEXT,
        birth_date TEXT,
        social_media TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // Tabla Products (Catálogo Offline)
    await db.execute('''
      CREATE TABLE products(
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        price REAL,
        category TEXT,
        image_url TEXT,
        hubId INTEGER,
        active INTEGER DEFAULT 1,
        disponible INTEGER DEFAULT 0
      )
    ''');

    // Tabla Orders (Pedidos)
    await db.execute('''
      CREATE TABLE orders(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        club_id INTEGER,
        membresia_id INTEGER,
        tipo_consumo TEXT, -- 'EN_LUGAR' o 'PARA_LLEVAR'
        observaciones TEXT, -- Nota general del pedido
        status TEXT, -- pending, preparing, ready, completed
        created_at TEXT,
        is_synced INTEGER DEFAULT 0, -- 0: No enviado al server, 1: Sincronizado
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');

    // Tabla Order Items
    await db.execute('''
      CREATE TABLE order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT,
        product_id TEXT,
        quantity INTEGER,
        note TEXT, -- Nota específica del producto
        FOREIGN KEY(order_id) REFERENCES orders(id),
        FOREIGN KEY(product_id) REFERENCES products(id)
      )
    ''');
    
    // NO insertar datos de seed - los productos deben venir del backend
    // await _seedData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Si la versión es vieja, agregamos las columnas nuevas
      // Nota: SQLite no soporta IF NOT EXISTS en ADD COLUMN en versiones viejas, 
      // pero aquí asumimos upgrade lineal v1 -> v2
      try {
        await db.execute('ALTER TABLE users ADD COLUMN birth_date TEXT');
        await db.execute('ALTER TABLE users ADD COLUMN social_media TEXT');
      } catch (e) {
        // Ignorar si ya existen (por si acaso el usuario corrió una versión intermedia)
        print("Error migrando columnas (pueden ya existir): $e");
      }
    }
    if (oldVersion < 3) {
      // Agregar columnas nuevas a products para soportar hubId y disponible
      try {
        await db.execute('ALTER TABLE products ADD COLUMN hubId INTEGER');
        await db.execute('ALTER TABLE products ADD COLUMN active INTEGER DEFAULT 1');
        await db.execute('ALTER TABLE products ADD COLUMN disponible INTEGER DEFAULT 0');
        // Eliminar productos de seed que no tienen hubId (son datos de prueba)
        await db.delete('products', where: 'hubId IS NULL');
      } catch (e) {
        print("Error migrando tabla products: $e");
      }
    }
    if (oldVersion < 4) {
      // Agregar columnas club_id y membresia_id a orders
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN club_id INTEGER');
        await db.execute('ALTER TABLE orders ADD COLUMN membresia_id INTEGER');
      } catch (e) {
        print("Error migrando tabla orders: $e");
      }
    }
    if (oldVersion < 5) {
      // Actualizar estructura de orders y order_items para eliminar precio y agregar tipoConsumo/nota
      try {
        // Agregar nuevas columnas a orders
        await db.execute('ALTER TABLE orders ADD COLUMN tipo_consumo TEXT');
        await db.execute('ALTER TABLE orders ADD COLUMN observaciones TEXT');
        // Eliminar columna total si existe (SQLite no soporta DROP COLUMN directamente)
        // En su lugar, crearemos una nueva tabla y migraremos datos
        
        // Agregar nota a order_items y eliminar price
        await db.execute('ALTER TABLE order_items ADD COLUMN note TEXT');
        // Eliminar price: SQLite no soporta DROP COLUMN, pero podemos ignorarlo en el código
      } catch (e) {
        print("Error migrando tabla orders/order_items: $e");
      }
    }
  }

  // Método deshabilitado - NO usar datos de seed
  // Los productos deben venir siempre del backend para evitar mostrar productos que no existen
  /*
  Future<void> _seedData(Database db) async {
    // Datos de ejemplo simulando la API
    final products = [
      {
        'id': '1',
        'name': 'Batido Fresa',
        'description': 'Delicioso batido nutricional sabor fresa.',
        'price': 25.0,
        'category': 'Batidos',
        'image_url': 'assets/images/shake_strawberry.png',
        'is_available': 1
      },
      {
        'id': '2',
        'name': 'Té de Hierbas',
        'description': 'Té energizante concentrado.',
        'price': 15.0,
        'category': 'Tés',
        'image_url': 'assets/images/tea_herbal.png',
        'is_available': 1
      },
      {
        'id': '3',
        'name': 'Aloe Vera',
        'description': 'Bebida refrescante de sábila.',
        'price': 12.0,
        'category': 'Aloes',
        'image_url': 'assets/images/aloe.png',
        'is_available': 1
      },
    ];

    for (var p in products) {
      await db.insert('products', p);
    }
  }
  */

  // Métodos CRUD genéricos
  Future<int> insert(String table, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAllRows(String table) async {
    Database db = await database;
    return await db.query(table);
  }

  Future<int> update(String table, Map<String, dynamic> row, String columnId) async {
    Database db = await database;
    String id = row[columnId];
    return await db.update(table, row, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, String id) async {
    Database db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
