import 'package:cashier/class/productclass.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Database Helper class
class DatabaseHelper {
  // Singleton pattern for database
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'product_inventory.db');
    return openDatabase(
      path,
      onCreate: (db, version) {
        // Create Users Table
        db.execute(
          '''CREATE TABLE users(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              email TEXT UNIQUE NOT NULL)''',
        );
        
        // Create Products Table
        db.execute(
          '''CREATE TABLE products(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              price REAL NOT NULL,
              stock INTEGER NOT NULL)''',
        );

        // Create Transactions Table
        db.execute(
          '''CREATE TABLE transactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              total REAL NOT NULL,
              cash REAL NOT NULL,
              change REAL NOT NULL,
              created_at DEFAULT CURRENT_TIMESTAMP)''',
        );

        // Create Transaction Items Table
        db.execute(
          '''CREATE TABLE transaction_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              transaction_id INTEGER NOT NULL,
              product_id INTEGER NOT NULL,
              qty INTEGER NOT NULL,
              price REAL NOT NULL,
              FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
              FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE)''',
        );
      },
      version: 1,
    );
  }

  // Insert a user
  Future<int> insertUser(String name, String email) async {
    final db = await database;
    return await db.insert(
      'users',
      {'name': name, 'email': email},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert a product
  Future<int> insertProduct(Productclass product) async {
    final db = await database;
    return await db.insert(
      'products',
      {'name': product.name, 'price': product.price, 'stock': product.stock},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  

  // // Insert a transaction
  // Future<int> insertTransaction(Transaction transaction) async {
  //   final db = await database;
  //   return await db.insert(
  //     'transactions',
  //     {'total': transaction.total, 'cash': transaction.cash, 'change': transaction.change},
  //     conflictAlgorithm: ConflictAlgorithm.replace,
  //   );
  // }

  // Insert a transaction item (linking product to transaction)
  // Future<int> insertTransactionItem(TransactionItem item) async {
  //   final db = await database;
  //   return await db.insert(
  //     'transaction_items',
  //     {
  //       'transaction_id': item.transactionId,
  //       'product_id': item.productId,
  //       'qty': item.qty,
  //       'price': item.price,
  //     },
  //     conflictAlgorithm: ConflictAlgorithm.replace,
  //   );
  // }

  // Get products
  Future<List<Productclass>> getProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) {
      return Productclass.fromMap(maps[i]);
    });
  }

  // // Get transactions
  // Future<List<Transaction>> getTransactions() async {
  //   final db = await database;
  //   final List<Map<String, dynamic>> maps = await db.query('transactions');
  //   return List.generate(maps.length, (i) {
  //     return Transaction.fromMap(maps[i]);
  //   });
  // }

  // Get transaction items
  // Future<List<TransactionItem>> getTransactionItems(int transactionId) async {
  //   final db = await database;
  //   final List<Map<String, dynamic>> maps = await db.query(
  //     'transaction_items',
  //     where: 'transaction_id = ?',
  //     whereArgs: [transactionId],
  //   );
  //   return List.generate(maps.length, (i) {
  //     return TransactionItem.fromMap(maps[i]);
  //   });
  // }
}
