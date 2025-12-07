// import 'dart:async';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';

// /// ----------------- Models -----------------
// class OfflineTransaction {
//   String userId;
//   double total;
//   double cash;
//   double change;
//   DateTime timestamp;
//   List<OfflineTransactionItem> items;

//   OfflineTransaction({
//     required this.userId,
//     required this.total,
//     required this.cash,
//     required this.change,
//     required this.timestamp,
//     required this.items,
//   });
// }

// class OfflineTransactionItem {
//   int productId;
//   String productName;
//   double price;
//   int qty;
//   bool isPromo;
//   int otherQty;

//   OfflineTransactionItem({
//     required this.productId,
//     required this.productName,
//     required this.price,
//     required this.qty,
//     required this.isPromo,
//     required this.otherQty,
//   });
// }

// /// ----------------- SQLite Helper -----------------
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
//     return await openDatabase(
//       path,
//       version: 1,
//       onCreate: _onCreate,
//     );
//   }

//   Future _onCreate(Database db, int version) async {
//     await db.execute('''
//       CREATE TABLE transactions(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         user_id TEXT,
//         total REAL,
//         cash REAL,
//         change REAL,
//         timestamp TEXT
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE transaction_items(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         transaction_id INTEGER,
//         product_id INTEGER,
//         product_name TEXT,
//         price REAL,
//         qty INTEGER,
//         is_promo INTEGER,
//         other_qty INTEGER,
//         FOREIGN KEY(transaction_id) REFERENCES transactions(id)
//       )
//     ''');
//   }

//   // Save transaction + items
//   Future<int> insertTransaction(OfflineTransaction tx) async {
//     final db = await database;

//     int txId = await db.insert('transactions', {
//       'user_id': tx.userId,
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

//   // Get all offline transactions
//   Future<List<Map<String, dynamic>>> getOfflineTransactions() async {
//     final db = await database;
//     return await db.query('transactions');
//   }

//   // Delete transaction
//   Future<void> deleteTransaction(int id) async {
//     final db = await database;
//     await db.delete('transaction_items', where: 'transaction_id = ?', whereArgs: [id]);
//     await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
//   }
// }

// /// ----------------- Offline Service -----------------
// class OfflineService {
//   static final OfflineService _instance = OfflineService._internal();
//   factory OfflineService() => _instance;
//   OfflineService._internal();

//   final OfflineDB _db = OfflineDB();

//   /// Check connectivity
//   Future<bool> isOnline() async {
//     var connectivity = await Connectivity().checkConnectivity();
//     return connectivity != ConnectivityResult.none;
//   }

//   /// Save transaction offline
//   Future<void> saveTransactionOffline(OfflineTransaction tx) async {
//     await _db.insertTransaction(tx);
//   }

//   /// Sync offline transactions to online
//   Future<void> syncOfflineTransactions(Future<void> Function(OfflineTransaction) onlineSave) async {
//     var offlineTx = await _db.getOfflineTransactions();

//     for (var txMap in offlineTx) {
//       int txId = txMap['id'];
//       var items = await (await _db.database).query(
//         'transaction_items',
//         where: 'transaction_id = ?',
//         whereArgs: [txId],
//       );

//       List<OfflineTransactionItem> itemList = items.map((i) => OfflineTransactionItem(
//   productId: (i['product_id'] as int),
//   productName: i['product_name'] as String,
//   price: (i['price'] as num).toDouble(), // SQLite may return int or double
//   qty: (i['qty'] as int),
//   isPromo: (i['is_promo'] as int) == 1,
//   otherQty: (i['other_qty'] as int),
// )).toList();

//       OfflineTransaction tx = OfflineTransaction(
//         userId: txMap['user_id'] ?? '',
//         total: txMap['total'],
//         cash: txMap['cash'],
//         change: txMap['change'],
//         timestamp: DateTime.parse(txMap['timestamp']),
//         items: itemList,
//       );

//       try {
//         await onlineSave(tx); // Supabase save function
//         await _db.deleteTransaction(txId);
//       } catch (e) {
//         print("Failed to sync transaction $txId: $e");
//       }
//     }
//   }
// }
