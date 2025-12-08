import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  Database? _database;

  // Get transaction items for a specific transaction
Future<List<Map<String, dynamic>>> getTransactionItemsForTransaction(int transactionId) async {
  final db = await database;
  return await db.query(
    'transaction_items',
    where: 'transaction_id = ?',
    whereArgs: [transactionId],
  );
}

Future<void> deleteItemsByTransaction(int transactionId) async {
  final db = await database;
  await db.delete(
    'transaction_items',
    where: 'transaction_id = ?',
    whereArgs: [transactionId],
  );
}

Future<List<Map<String, dynamic>>> getTransactionsWithItemsFiltered(
    String startDate, String endDate) async {

  final db = await database;

  return await db.rawQuery('''
    SELECT 
      t.id AS transaction_id,
      t.cash,
      t.change,
      t.created_at,
      ti.id AS item_id,
      ti.product_id,
      ti.product_name,
      ti.qty,
      ti.price,
      ti.is_promo,
      ti.other_qty
    FROM transactions t
    LEFT JOIN transaction_items ti
    ON t.id = ti.transaction_id
    WHERE date(t.created_at) BETWEEN date(?) AND date(?)
    ORDER BY t.created_at DESC
  ''', [startDate, endDate]);
}




Future<List<Map<String, dynamic>>> getTransactionsWithItems() async {
  final db = await database;
  return await db.rawQuery('''
    SELECT 
      t.id AS transaction_id,
      t.cash,
      t.change,
      t.created_at,
      ti.id AS item_id,
      ti.product_id,
      ti.product_name,
      ti.qty,
      ti.price,
      ti.is_promo,
      ti.other_qty
    FROM transactions t
    LEFT JOIN transaction_items ti
    ON t.id = ti.transaction_id
    ORDER BY t.created_at DESC
  ''');
}

// Get transaction items with product info
Future<List<Map<String, dynamic>>> getTransactionItemsWithProduct(int transactionId) async {
  final db = await database;
  return await db.rawQuery('''
    SELECT ti.id as item_id, ti.transaction_id, ti.qty, ti.price, ti.is_promo, 
           p.name as product_name, t.total, t.cash, t.change, t.created_at
    FROM transaction_items ti
    INNER JOIN transactions t ON t.id = ti.transaction_id
    INNER JOIN products p ON p.id = ti.product_id
    WHERE ti.transaction_id = ?
    ORDER BY ti.id ASC
  ''', [transactionId]);
}
//BAG-O----------------------------------------------------------------
Future<List<Map<String, dynamic>>> getUnsyncedTransactions() async {
  final db = await database;
  return await db.query('transactions', where: 'is_synced = ?', whereArgs: [0]);
}

Future<List<Map<String, dynamic>>> getItemsForTransaction(int trxId) async {
  final db = await database;
  return await db.query(
    'transaction_items',
    where: 'transaction_id = ? AND is_synced = ?',
    whereArgs: [trxId, 0],
  );
}

Future<void> markTransactionSynced(int id) async {
  final db = await database;
  await db.update(
    'transactions',
    {'is_synced': 1},
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<void> markItemSynced(int itemId) async {
  final db = await database;
  await db.update(
    'transaction_items',
    {'is_synced': 1},
    where: 'id = ?',
    whereArgs: [itemId],
  );
}


//BAG-O-------------------------------------------------------------

Future<void> printAllTransactions() async {
  final db = await database;
  final List<Map<String, dynamic>> transactions = await db.query('transactions');
  
  if (transactions.isEmpty) {
    print("Walay transactions sa local DB");
  } else {
    print("Transactions in local DB:");
    for (var t in transactions) {
      print(t);
    }
  }
}

Future<void> backupDatabaseToDownloads() async {
  if (await Permission.storage.request().isGranted) {
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app.db'));

    final downloadsDir = Directory('/storage/emulated/0/Download'); // Android downloads
    final backupFile = File(join(downloadsDir.path, 'app_backup.db'));

    await dbFile.copy(backupFile.path);
    print("Backup saved to Downloads: ${backupFile.path}");
  } else {
    print("Storage permission denied");
  }
}




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
            other_qty INTEGER,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        // Transactions table
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY,
            total REAL NOT NULL,
            cash REAL NOT NULL,
            change REAL NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            is_synced INTEGER DEFAULT 0
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
            is_synced INTEGER DEFAULT 0,
            supabase_id INTEGER, 
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
