import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalDatabase {
  Database? _database;
  DatabaseExecutor? _txn;

  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

Future<void> markTransactionAsSynced(int id) async {
  final db = await database;
  await db.update(
    'transactions',
    {'is_synced': 1},
    where: 'id = ?',
    whereArgs: [id],
  );
}
  Future<List<String>> getAllTableNames() async {
    final db = await database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
    );
    return tables.map((e) => e['name'].toString()).toList();
  }

  /// GET ALL ROWS FROM A TABLE
  Future<List<Map<String, dynamic>>> getAllRows(String tableName) async {
    final db = await database;
    return await db.query(tableName);
  }

// Get latest stock
Future<Map<String, dynamic>?> getLatestStock(int productId) async {
  final db = await database;
  final res = await db.query(
    'latest_stock_detail',
    where: 'product_id = ?',
    whereArgs: [productId],
  );
  return res.isNotEmpty ? res.first : null;
}

// Insert latest stock
Future<void> insertLatestStock(int productId, int oldStock, int latestStock) async {
  final db = await database;
  await db.insert('latest_stock_detail', {
    'product_id': productId,
    'old_stock': oldStock,
    'latest_stock': latestStock,
  });
}

// Update latest stock
Future<void> updateLatestStock(int productId, int oldStock, int latestStock) async {
  final db = await database;
  await db.update(
    'latest_stock_detail',
    {'old_stock': oldStock, 'latest_stock': latestStock},
    where: 'product_id = ?',
    whereArgs: [productId],
  );
}


// ------------------------- DATABASE GETTER ------------------------- //
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }
// ------------------------- DATABASE INITIALIZATION ----------------- //
    Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');

    final db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migration for product_stock_history column fixes
        if (oldVersion < 4) {
          // Rename old table
          await db.execute(
              'ALTER TABLE product_stock_history RENAME TO old_product_stock_history');

          // Create new table with correct column name
          await db.execute('''
            CREATE TABLE product_stock_history(
              id INTEGER PRIMARY KEY,
              product_id INTEGER,
              old_stock INTEGER,
              qty_changed INTEGER,
              new_stock INTEGER,
              type TEXT,
              created_at TEXT,
              is_synced INTEGER
            )
          ''');

          // Copy old data
          await db.execute('''
            INSERT INTO product_stock_history (id, product_id, old_stock, qty_changed, new_stock, type, created_at, is_synced)
SELECT id, product_id, old_stock, COALESCE(qty_changed, 0), new_stock, type, created_at, is_synced
FROM old_product_stock_history
          ''');

          // Drop old table
          await db.execute('DROP TABLE old_product_stock_history');
        }
      },
    );

    await db.execute('PRAGMA foreign_keys = ON');
    return db;
  }

  Future<void> _createTables(Database db) async {
    // Products table

    await db.execute('''
  CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT
  )
''');

    await db.execute('''
  CREATE TABLE IF NOT EXISTS products_offline (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    price REAL NOT NULL,
    stock INTEGER NOT NULL,
    is_promo INTEGER DEFAULT 0,
    other_qty INTEGER DEFAULT 0,
    is_synced INTEGER DEFAULT 0
  )
''');
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL,
        is_promo INTEGER DEFAULT 0,
        other_qty INTEGER,
        is_synced INTEGER DEFAULT 0,
        client_uuid TEXT UNIQUE,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    

    // Table to keep track of latest stock for each product
await db.execute('''
  CREATE TABLE IF NOT EXISTS latest_stock_detail (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER UNIQUE,
    old_stock INTEGER,
    latest_stock INTEGER
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
        is_synced INTEGER DEFAULT 0,
        client_uuid TEXT UNIQUE
      )
    ''');

    // Product stock history
    await db.execute('''
      CREATE TABLE product_stock_history(
        id INTEGER PRIMARY KEY,
        product_id INTEGER,
        old_stock INTEGER,
        qty_changed INTEGER,
        new_stock INTEGER,
        type TEXT,
        created_at TEXT,
        is_synced INTEGER,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Transaction items
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

    // Stock update queue
    await db.execute('''
      CREATE TABLE stock_update_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        qty INTEGER NOT NULL,
        type TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');
  }

// ------------------- GET MONTHLY SALES ------------------- //

Future<List<Map<String, dynamic>>> getMonthlySales() async {
  final db = await database;

  final result = await db.rawQuery('''
    SELECT 
      strftime('%Y-%m', created_at) AS month,
      SUM(total) AS revenue,
      COUNT(id) AS total_transactions
    FROM transactions
    GROUP BY strftime('%Y-%m', created_at)
    ORDER BY month
  ''');

  return result;
}
// ------------------------------ GET MONTHLY ITEMS -------------------------------- //
Future<List<Map<String, dynamic>>> getMonthlyItems(String month) async {
  final db = await database;

  return await db.rawQuery('''
    SELECT 
      ti.product_name,
      ti.qty,
      ti.price
    FROM transaction_items ti
    JOIN transactions t ON ti.transaction_id = t.id
    WHERE strftime('%Y-%m', t.created_at) = ?
  ''', [month]);
}

// ------------------- INSERT STOCK UPDATE ------------------- //
Future<int> insertStockUpdate(int productId, int newStock) async {
  // 🔑 Get database instance
  final db = await database;

  // ➕ Insert new stock update into 'stock_updates' table
  // - 'product_id': ID of the product
  // - 'new_stock': updated stock quantity
  // - 'synced': 0 means not yet synced with server
  // - 'created_at': timestamp of update
  return await db.insert('stock_updates', {
    'product_id': productId,
    'new_stock': newStock,
    'synced': 0,
    'created_at': DateTime.now().toIso8601String(),
  });
}
// ------------------- GET UNSYNCED STOCK UPDATES ------------------- //
Future<List<Map<String, dynamic>>> getUnsyncedStockUpdates() async {
  // 🔑 Get database instance
  final db = await database;

  // 📋 Query 'stock_update_queue' table for updates that are not yet synced
  // - 'is_synced = 0' means the stock update hasn't been sent to the server
  return await db.query(
    'stock_update_queue',
    where: 'is_synced = ?',
    whereArgs: [0],
  );
}
// ------------------- MARK STOCK UPDATE AS SYNCED ------------------- //
Future<int> markStockUpdateSynced(int id) async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Update 'is_synced' to 1 for the given stock update ID
  // - Marks this stock update as already synced to the server
  return await db.update(
    'stock_update_queue',
    {'is_synced': 1},
    where: 'id = ?',
    whereArgs: [id],
  );
}
// ------------------- GET ITEMS FOR A SPECIFIC TRANSACTION ------------------- //
Future<List<Map<String, dynamic>>> getTransactionItemsForTransaction(
  int transactionId,
) async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Fetch all items linked to a specific transaction ID
  return await db.query(
    'transaction_items',
    where: 'transaction_id = ?',
    whereArgs: [transactionId],
  );
}
// ------------------- DELETE ITEMS FOR A SPECIFIC TRANSACTION ------------------- //
Future<void> deleteItemsByTransaction(int transactionId) async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Delete all items linked to the given transaction ID
  await db.delete(
    'transaction_items',
    where: 'transaction_id = ?',
    whereArgs: [transactionId],
  );
}
 // ------------------- GET TRANSACTIONS WITH ITEMS FILTERED BY DATE RANGE ------------------- //
Future<List<Map<String, dynamic>>> getTransactionsWithItemsFiltered(
  String startDate,
  String endDate,
) async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Query transactions joined with their items, filtered by the given date range
  return await db.rawQuery(
    '''
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
  ''',
    [startDate, endDate],
  );
}
 // ------------------- GET ALL TRANSACTIONS WITH THEIR ITEMS ------------------- //
Future<List<Map<String, dynamic>>> getTransactionsWithItems() async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Fetch all transactions ordered by newest first
  final tx = await db.query("transactions", orderBy: "created_at DESC");

  List<Map<String, dynamic>> result = [];

  for (final t in tx) {
    // 🔧 Ensure we get the correct transaction ID
    final transactionId = t["transaction_id"] ?? t["id"]; // FIX: use the correct ID

    // ✅ Fetch all items linked to this transaction
    final items = await db.query(
      "transaction_items",
      where: "transaction_id = ?",
      whereArgs: [transactionId],
    );

    // 🔹 Add transaction and its items to result
    result.add({
      "transaction_id": transactionId,
      "total": t["total"],
      "cash": t["cash"],
      "change": t["change"],
      "created_at": t["created_at"],
      "items": items,
    });
  }
  return result;
}
// ------------------- GET TRANSACTION ITEMS WITH PRODUCT DETAILS ------------------- //
Future<List<Map<String, dynamic>>> getTransactionItemsWithProduct(
  int transactionId,
) async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Query transaction items with joined product info and transaction totals
  return await db.rawQuery(
    '''
    SELECT ti.id as item_id, ti.transaction_id, ti.qty, ti.price, ti.is_promo, 
           p.name as product_name, t.total, t.cash, t.change, t.created_at
    FROM transaction_items ti
    INNER JOIN transactions t ON t.id = ti.transaction_id
    INNER JOIN products p ON p.id = ti.product_id
    WHERE ti.transaction_id = ?
    ORDER BY ti.id ASC
  ''',
    [transactionId],
  );
}
// ------------------- GET UNSYNCED TRANSACTIONS ------------------- //
Future<List<Map<String, dynamic>>> getUnsyncedTransactions() async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Fetch all transactions that have not been synced to server
  return await db.rawQuery(
    'SELECT * FROM transactions WHERE is_synced = 0',
  );
}
// ------------------- GET UNSYNCED ITEMS FOR A TRANSACTION ------------------- //
Future<List<Map<String, dynamic>>> getItemsForTransaction(int trxId) async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Fetch all items for a specific transaction that are not yet synced
  return await db.query(
    'transaction_items',
    where: 'transaction_id = ? AND is_synced = ?',
    whereArgs: [trxId, 0],
  );
}

// ------------------- MARK TRANSACTION AS SYNCED ------------------- //
Future<void> markTransactionSynced(int id) async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Update the 'is_synced' flag to 1 for the given transaction
  await db.update(
    'transactions',
    {'is_synced': 1},
    where: 'id = ?',
    whereArgs: [id],
  );
}

 // ------------------- MARK TRANSACTION ITEM AS SYNCED ------------------- //
Future<void> markItemSynced(int itemId) async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Update the 'is_synced' flag to 1 for the given transaction item
  await db.update(
    'transaction_items',
    {'is_synced': 1},
    where: 'id = ?',
    whereArgs: [itemId],
  );
}

// ------------------- PRINT ALL TRANSACTIONS ------------------- //
Future<void> printAllTransactions() async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Fetch all transactions from local DB
  final List<Map<String, dynamic>> transactions = await db.query('transactions');

  // 🖨️ Print transactions or message if empty
  if (transactions.isEmpty) {
    print("Walay transactions sa local DB"); // No transactions found
  } else {
    print("Transactions in local DB:");
    for (var t in transactions) {
      print(t); // Print each transaction
    }
  }
}



// ------------------- SET LAST PRODUCT SYNC TIMESTAMP ------------------- //
Future<void> setLastProductSync(DateTime timestamp) async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Insert or update the last product sync timestamp in 'meta' table
  await db.insert(
    'meta',
    {'key': 'last_product_sync', 'value': timestamp.toIso8601String()},
    conflictAlgorithm: ConflictAlgorithm.replace, // Replace if key exists
  );
}


// ------------------- Get Last Product Sync Timestamp ------------------- //
Future<DateTime?> getLastProductSync() async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Query the 'meta' table for the last product sync timestamp
  final result = await db.query(
    'meta',
    where: 'key = ?',
    whereArgs: ['last_product_sync'],
  );

  // ❌ If no record found, return null
  if (result.isEmpty) return null;

  // ✅ Parse and return the timestamp
  return DateTime.parse(result.first['value'] as String);
}

// ------------ PRODUCTS: Get Stock of a Specific Product ----------------- //
Future<int?> getProductStock(int productId) async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Query 'products' table to get stock for given productId
  final result = await db.query(
    'products',
    columns: ['stock'],        // only fetch stock column
    where: 'id = ?',           // filter by product ID
    whereArgs: [productId],
    limit: 1,                  // only one row expected
  );

  // ❌ If product not found, return null
  if (result.isEmpty) return null;

  // ✅ Return the stock value as int
  return result.first['stock'] as int;
}




// ------------------- STOCK UPDATE QUEUE: Insert a new stock update ------------------- //
Future<int> insertStockUpdateQueue1({
  required int productId,
  required int qty,
  required String type,  // e.g., SALE, ADJUSTMENT, RETURN
}) async {
  // 🔑 Get database instance
  final db = await database;

  // ✅ Insert a new row into 'stock_update_queue'
  return await db.insert(
    'stock_update_queue',
    {
      'product_id': productId,          // product affected
      'qty': qty,                        // quantity changed
      'type': type,                      // type of update
      'is_synced': 0,                    // default unsynced
      'created_at': DateTime.now().toIso8601String(),  // timestamp
    },
  );
}



// ------------------- DATABASE BACKUP ------------------- //
// 🔹 Copies local SQLite database to Android Downloads folder
Future<void> backupDatabaseToDownloads() async {
  // 🔑 Request storage permission
  if (await Permission.storage.request().isGranted) {
    // 🔹 Get path to local database
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'app.db'));

    // 🔹 Set backup path in Downloads folder
    final downloadsDir = Directory('/storage/emulated/0/Download'); // Android downloads
    final backupFile = File(join(downloadsDir.path, 'app_backup.db'));

    // 🔹 Copy database to backup location
    await dbFile.copy(backupFile.path);
    print("Backup saved to Downloads: ${backupFile.path}");
  } else {
    // ❌ Permission denied
    print("Storage permission denied");
  }
}
// ------------------------------- PRODUCTS CRUD -------------------------------------- //
// 🔹 Insert a new product or update if exists
Future<int> insertProduct({
  required int id,
  required String name,
  required double price,
  required int stock,
  bool isPromo = false,
  int otherQty = 0,
  String? clientUuid, // <- add this
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
      'client_uuid': clientUuid, // <- save it
    },
    conflictAlgorithm: ConflictAlgorithm.replace, // update if exists
  );
}

// 🔹 Fetch all products from local DB
Future<List<Map<String, dynamic>>> getProducts() async {
  final db = await database;
  return await db.query('products');
}

// 🔹 Delete a product by ID
Future<int> deleteProduct(int id) async {
  final db = await database;
  return await db.delete('products', where: 'id = ?', whereArgs: [id]);
}

// 🔹 Update stock for a specific product
Future<int> updateProductStock(int id, int stock) async {
  final db = await database;
  return await db.update(
    'products',
    {'stock': stock},
    where: 'id = ?',
    whereArgs: [id],
  );
}



// ------------------- TRANSACTIONS CRUD ------------------- //
// 🔹 Insert a new transaction (ignores conflict if ID exists)
Future<int> insertTransaction({
  required int id,
  required double total,
  required double cash,
  required double change,
  String? createdAt,
  int isSynced = 0, // default 0 = not synced
}) async {
  final db = await database;
  await db.insert(
    'transactions',
    {
      'id': id,
      'total': total,
      'cash': cash,
      'change': change,
      'created_at': createdAt,
      'is_synced': isSynced,
    },
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
  return id; // return the transaction ID
}

// 🔹 Fetch all transactions from local DB
Future<List<Map<String, dynamic>>> getTransactions() async {
  final db = await database;
  return await db.query('transactions');
}

// 🔹 Delete a transaction by ID
Future<int> deleteTransaction(int id) async {
  final db = await database;
  return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
}


  // ------------------- TRANSACTION ITEMS -------------------

// ------------------- TRANSACTION ITEMS CRUD ------------------- //
// 🔹 Insert a new transaction item (replace if ID exists)
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

// 🔹 Fetch all transactions (main table)
Future<List<Map<String, dynamic>>> getAllTransactions() async {
  final db = await database;
  final result = await db.query(
    'transactions',
    orderBy: 'created_at DESC',
  );
  return result;
}

// 🔹 Fetch all items for a specific transaction
Future<List<Map<String, dynamic>>> getTransactionItems(int transactionId) async {
  final db = await database;
  final result = await db.query(
    'transaction_items',
    where: 'transaction_id = ?',
    whereArgs: [transactionId],
  );
  return result;
}

// 🔹 Delete a transaction item by ID
Future<int> deleteTransactionItem(int id) async {
  final db = await database;
  return await db.delete(
    'transaction_items',
    where: 'id = ?',
    whereArgs: [id],
  );
}
Future<void> insertStockHistory({
  required int id,
  required int productId,
  required int oldStock,
  required int qtyChanged,
  required int newStock,
  required String type, // SALE, RESTOCK, ADJUSTMENT
  required String createdAt,
  required int synced, // 0 = offline, 1 = online
}) async {
  final db = await database;
  await db.insert(
    'product_stock_history',
    {
      'id': id,
      'product_id': productId,
      'old_stock': oldStock,
      'qty_changed': qtyChanged,
      'new_stock': newStock,
      'type': type,
      'created_at': createdAt,
      'is_synced': synced,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}


Future<bool> productExists(int id) async {
  final db = await database;
  final res = await db.query('products', where: 'id = ?', whereArgs: [id]);
  return res.isNotEmpty;
}


}
