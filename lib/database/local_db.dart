import 'dart:io';
import 'package:cashier/services/transaction_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  Database? _database;
  // ------------------- MONTHLY SALES (AUTO-GENERATE) -------------------

  Future<List<Map<String, dynamic>>> getMonthlySales() async {
    final db = await database;

    // GROUP all transactions by year-month
    final result = await db.rawQuery('''
    SELECT 
      strftime('%Y-%m', created_at) AS month,
      SUM(total) AS revenue,
      COUNT(id) AS total_transactions
    FROM transactions
    GROUP BY strftime('%Y-%m', created_at)
    ORDER BY month DESC
  ''');

    return result;
  }

  // Insert stock update to queue
  Future<int> insertStockUpdate(int productId, int newStock) async {
    final db = await database;
    return await db.insert('stock_updates', {
      'product_id': productId,
      'new_stock': newStock,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Get unsynced stock updates
  Future<List<Map<String, dynamic>>> getUnsyncedStockUpdates() async {
    final db = await database;
    return await db.query(
      'stock_update_queue',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  // Mark stock update as synced
  Future<int> markStockUpdateSynced(int id) async {
    final db = await database;
    return await db.update(
      'stock_update_queue',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get transaction items for a specific transaction
  Future<List<Map<String, dynamic>>> getTransactionItemsForTransaction(
    int transactionId,
  ) async {
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
    String startDate,
    String endDate,
  ) async {
    final db = await database;

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

  // ---------------------------------------------------------------//
  //                     HISTORY
  //---------------------------------------------------------------//
  Future<List<Map<String, dynamic>>> getTransactionsWithItems() async {
    final db = await database;

    // Fetch all transactions
    final tx = await db.query("transactions", orderBy: "created_at DESC");

    List<Map<String, dynamic>> result = [];

    for (final t in tx) {
      final transactionId =
          t["transaction_id"] ?? t["id"]; // FIX: use the correct ID

      // Fetch items linked to this transaction
      final items = await db.query(
        "transaction_items",
        where: "transaction_id = ?",
        whereArgs: [transactionId],
      );

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

  // Get transaction items with product info
  Future<List<Map<String, dynamic>>> getTransactionItemsWithProduct(
    int transactionId,
  ) async {
    final db = await database;
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

  //BAG-O----------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getUnsyncedTransactions() async {
    final db = await database;
    return await db.query(
      'transactions',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
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
    final List<Map<String, dynamic>> transactions = await db.query(
      'transactions',
    );

    if (transactions.isEmpty) {
      print("Walay transactions sa local DB");
    } else {
      print("Transactions in local DB:");
      for (var t in transactions) {
        print(t);
      }
    }
  }



  Future<void> setLastProductSync(DateTime timestamp) async {
  final db = await database;
  await db.insert(
    'meta',
    {'key': 'last_product_sync', 'value': timestamp.toIso8601String()},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<DateTime?> getLastProductSync() async {
  final db = await database;
  final result = await db.query(
    'meta',
    where: 'key = ?',
    whereArgs: ['last_product_sync'],
  );
  if (result.isEmpty) return null;
  return DateTime.parse(result.first['value'] as String);
}

//--------------------------------------------------------
//--------------------------------------------------------
//--------------------------------------------------------
//--------------------------------------------------------

Future<void> syncQueuedStockWithServer(TransactionService transactionService) async {
    final queuedStock = await getUnsyncedStockUpdates(); // returns all rows where is_synced = 0

    if (queuedStock.isEmpty) {
      print("No queued stock updates to sync.");
      return;
    }

    for (var item in queuedStock) {
      try {
        final int queueId = item['id'] as int;
        final int productId = item['product_id'] as int;
        final int qty = item['qty'] as int;
        final String type = item['type'] as String;

        // Get current stock from local DB
        int? localStock = await getProductStock(productId);
        if (localStock == null) {
          print("Product ID $productId not found in local DB.");
          continue;
        }

        // Call your existing TransactionService method to update stock online
        await transactionService.updateStock(
          productId: productId,
          newStock: localStock, // the local stock after the transaction
        );

        // Mark queue item as synced
        await markStockUpdateSynced(queueId);

        print("Synced Product ID $productId | Qty: $qty | Type: $type");
      } catch (e) {
        print("Failed to sync queue item ${item['id']}: $e");
      }
    }

    print("All queued stock updates synced.");
  }
  Future<int?> getProductStock(int productId) async {
    final db = await database;

    final result = await db.query(
      'products',
      columns: ['stock'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return result.first['stock'] as int;
  }



Future<int> insertStockUpdateQueue1({
  required int productId,
  required int qty,
  required String type,
}) async {
  final db = await database;
  return await db.insert(
    'stock_update_queue',
    {
      'product_id': productId,
      'qty': qty,
      'type': type,
      'is_synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    },
  );
}





//--------------------------------------------------------
//--------------------------------------------------------
//--------------------------------------------------------

  Future<void> backupDatabaseToDownloads() async {
    if (await Permission.storage.request().isGranted) {
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'app.db'));

      final downloadsDir = Directory(
        '/storage/emulated/0/Download',
      ); // Android downloads
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
      version: 2,
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
            is_synced INTEGER DEFAULT 0,
            client_uuid TEXT UNIQUE
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

        await db.execute('''
         CREATE TABLE IF NOT EXISTS stock_update_queue(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
               qty INTEGER NOT NULL,            -- pila ka gi-minus
            type TEXT NOT NULL,              -- SALE, ADJUSTMENT, RETURN
   
            is_synced INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Add new table for existing installations
        if (oldVersion < 2) {
          await db.execute('''
          CREATE TABLE stock_update_queue(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            qty INTEGER NOT NULL,            -- pila ka gi-minus
            type TEXT NOT NULL,              -- SALE, ADJUSTMENT, RETURN
   
            is_synced INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
          )
         ''');
        }
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
    return await db.insert('transactions', {
      'id': id,
      'total': total,
      'cash': cash,
      'change': change,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    return await db.insert('transaction_items', {
      'id': id,
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'qty': qty,
      'price': price,
      'is_promo': isPromo ? 1 : 0,
      'other_qty': otherQty,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }



// Get all transactions
Future<List<Map<String, dynamic>>> getAllTransactions() async {
  final db = await database;
  final result = await db.query(
    'transactions',
    orderBy: 'created_at DESC',
    
  );
  return result;
}
// Get items for a specific transaction
Future<List<Map<String, dynamic>>> getTransactionItems(int transactionId) async {
  final db = await database;
  final result = await db.query(
    'transaction_items',
    where: 'transaction_id = ?',
    whereArgs: [transactionId],
  );
  return result;
  
}


  Future<int> deleteTransactionItem(int id) async {
    final db = await database;
    return await db.delete(
      'transaction_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }



  // ------------------------------------------------------------- //
  //                  MONTHLY REPORTS (NEW)
  // ------------------------------------------------------------- //

  /// AUTO-GENERATE MONTHLY SALES RESULTS
  ///
  /// Output Example:
  ///   month: "2025-01"
  ///   revenue: 45000
  ///   profit: 45000 (no cost column in your DB)
  ///
}
