import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Products table
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            stock INTEGER NOT NULL,
            is_promo INTEGER DEFAULT 0,
            other_qty INTEGER
          )
        ''');

        // Transactions table
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY,
            total REAL NOT NULL,
            cash REAL NOT NULL,
            change REAL NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Transaction items table
        await db.execute('''
          CREATE TABLE transaction_items(
            id INTEGER PRIMARY KEY,
            transaction_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            product_name TEXT NOT NULL,
            qty INTEGER NOT NULL,
            price REAL NOT NULL,
            is_promo INTEGER DEFAULT 0,
            other_qty INTEGER,
            FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
            FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
          )
        ''');
      },
    );

    // Enable foreign key support
    await db.execute('PRAGMA foreign_keys = ON');

    return db;
  }

  // ------------------- PRODUCTS -------------------

  Future<int> insertProduct({
    required int id,
    required String name,
    required double price,
    required int stock,
    bool isPromo = false,
    int otherQty = 0,
  }) async {
    final db = await database;
    return await db.insert(
      'products',
      {
        'id': id,
        'name': name,
        'price': price,
        'stock': stock,
        'is_promo': isPromo ? 1 : 0,
        'other_qty': otherQty,
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // update if exists
    );
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query('products');
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateProductStock(int id, int stock) async {
    final db = await database;
    return await db.update(
      'products',
      {'stock': stock},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ------------------- TRANSACTIONS -------------------

  Future<int> insertTransaction({
    required int id,
    required double total,
    required double cash,
    required double change,
    String? createdAt,
  }) async {
    final db = await database;
    return await db.insert(
      'transactions',
      {
        'id': id,
        'total': total,
        'cash': cash,
        'change': change,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    return await db.query('transactions');
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------- TRANSACTION ITEMS -------------------

  Future<int> insertTransactionItem({
    required int id,
    required int transactionId,
    required int productId,
    required String productName,
    required int qty,
    required double price,
    bool isPromo = false,
    int otherQty = 0,
  }) async {
    final db = await database;
    return await db.insert(
      'transaction_items',
      {
        'id': id,
        'transaction_id': transactionId,
        'product_id': productId,
        'product_name': productName,
        'qty': qty,
        'price': price,
        'is_promo': isPromo ? 1 : 0,
        'other_qty': otherQty,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionItems() async {
    final db = await database;
    return await db.query('transaction_items');
  }

  Future<int> deleteTransactionItem(int id) async {
    final db = await database;
    return await db.delete('transaction_items', where: 'id = ?', whereArgs: [id]);
  }
}
