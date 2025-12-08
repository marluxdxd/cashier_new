// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';

// class OfflineDB {
//   static final OfflineDB _instance = OfflineDB._internal();
//   factory OfflineDB() => _instance;
//   OfflineDB._internal();

//   static Database? _database;

//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDB();
//     return _database!;
//   }

//   Future<Database> _initDB() async {
//     final path = join(await getDatabasesPath(), 'offline_pos.db');
//     final db = await openDatabase(
//       path,
//       version: 1,
//       onCreate: _onCreate,
//     );

//     await db.execute('PRAGMA foreign_keys = ON;'); // enable FK
//     return db;
//   }

//   Future _onCreate(Database db, int version) async {
//     // Products table
//     await db.execute('''
//       CREATE TABLE products(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         name TEXT NOT NULL,
//         price REAL NOT NULL,
//         stock INTEGER NOT NULL,
//         is_promo INTEGER DEFAULT 0,
//         other_qty INTEGER,
//         type TEXT DEFAULT 'add'
//       )
//     ''');

//     // Transactions table
//     await db.execute('''
//       CREATE TABLE transactions(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         total REAL NOT NULL,
//         cash REAL NOT NULL,
//         change REAL NOT NULL,
//         timestamp TEXT NOT NULL
//       )
//     ''');

//     // Transaction items
//     await db.execute('''
//       CREATE TABLE transaction_items(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         transaction_id INTEGER NOT NULL,
//         product_id INTEGER NOT NULL,
//         product_name TEXT NOT NULL,
//         price REAL NOT NULL,
//         qty INTEGER NOT NULL,
//         is_promo INTEGER DEFAULT 0,
//         other_qty INTEGER,
//         FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
//         FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
//       )
//     ''');
//   }

//   /// ----------------- Products -----------------
//   Future<int> addProduct(Product product) async {
//     final db = await database;
//     return await db.insert('products', product.toMap());
//   }

//   Future<List<Product>> fetchProducts() async {
//     final db = await database;
//     final result = await db.query('products');
//     return result.map((e) => Product.fromMap(e)).toList();
//   }

//   Future<int> updateProduct(Product product) async {
//     final db = await database;
//     return await db.update(
//       'products',
//       product.toMap(),
//       where: 'id = ?',
//       whereArgs: [product.id],
//     );
//   }

//   Future<int> deleteProduct(int id) async {
//     final db = await database;
//     return await db.delete('products', where: 'id = ?', whereArgs: [id]);
//   }

//   /// ----------------- Transactions -----------------
//   Future<int> insertTransaction(OfflineTransaction tx) async {
//     final db = await database;
//     int txId = await db.insert('transactions', {
//       'total': tx.total,
//       'cash': tx.cash,
//       'change': tx.change,
//       'timestamp': tx.timestamp.toIso8601String(),
//     });

//     for (var item in tx.items) {
//       await db.insert('transaction_items', {
//         'transaction_id': txId,
//         'product_id': item.productId,
//         'product_name': item.productName,
//         'price': item.price,
//         'qty': item.qty,
//         'is_promo': item.isPromo ? 1 : 0,
//         'other_qty': item.otherQty,
//       });
//     }

//     return txId;
//   }

//   Future<List<Map<String, dynamic>>> getOfflineTransactions() async {
//     final db = await database;
//     return await db.query('transactions');
//   }

//   Future<void> deleteTransaction(int id) async {
//     final db = await database;
//     await db.delete('transaction_items', where: 'transaction_id = ?', whereArgs: [id]);
//     await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
//   }
// }
