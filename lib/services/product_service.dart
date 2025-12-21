import 'dart:async';
import 'dart:io';
import 'package:cashier/class/productclass.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

String generateUniqueId({String prefix = "S"}) {
  return "$prefix${DateTime.now().millisecondsSinceEpoch}";
}

class ProductService {
  final supabase = SupabaseConfig.supabase;
  final localDb = LocalDatabase();

  late final Connectivity _connectivity;
  late final StreamSubscription _connectivitySub;

  void listenToConnectivity(VoidCallback onOnline) {
    _connectivity = Connectivity();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((
      result,
    ) async {
      if (result != ConnectivityResult.none) {
        final online = await isOnline1();
        if (online) {
          await syncOfflineProducts();
          await syncOfflineStockHistory();
          await syncOfflineTransactions();
          onOnline(); // refresh UI
        }
      }
    });
  }

  void disposeConnectivity() {
    _connectivitySub.cancel();
  }

  Future<bool> isOnline() async {
    var connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }

  Future<List<Productclass>> getAllProducts() async {
    final online = await isOnline();

    if (online) {
      // Fetch from Supabase
      final data = await supabase.from('products').select();

      for (var p in data) {
        final int productId = p['id'] as int;

        // 🔑 CHECK IF PRODUCT EXISTS LOCALLY
        final int? localStock = await localDb.getProductStock(productId);

        await localDb.insertProduct(
          id: productId,
          name: p['name'] as String,
          price: (p['price'] as num).toDouble(),

          // ✅ PROTECT LOCAL STOCK
          stock: localStock ?? (p['stock'] as int),

          isPromo: p['is_promo'] as bool? ?? false,
          otherQty: p['other_qty'] as int? ?? 0,
          clientUuid: p['client_uuid']?.toString(),
        );
      }

      return (data as List<dynamic>)
          .map((e) => Productclass.fromMap(e as Map<String, dynamic>))
          .toList();
    } else {
      // Fetch from local DB
      final localData = await localDb.getProducts();

      final filtered = localData.where((e) {
        final uuid = e['client_uuid'];
        return uuid != null && uuid.toString().isNotEmpty;
      }).toList();

      return filtered
          .map(
            (e) => Productclass(
              id: e['id'],
              name: e['name'],
              price: e['price'],
              stock: e['stock'],
              isPromo: e['is_promo'] == 1,
              otherQty: e['other_qty'] ?? 0,
            ),
          )
          .toList();
    }
  }

  Future<void> reduceStock({
    required int productId,
    required int qtySold,
    required String changeType,
  }) async {
    final db = await localDb.database;

    // Get current stock
    final productList = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (productList.isEmpty) return;

    final product = productList.first;
    final int oldStock = product['stock'] as int;
    final int newStock = oldStock - qtySold;

    if (newStock < 0) {
      print("Cannot reduce stock below 0 for product $productId");
      return;
    }

    // Update local stock
    await localDb.updateProductStock(productId, newStock);

    // Insert stock history
    final historyId = generateUniqueId(prefix: "T").hashCode.abs();
    final transDate = DateTime.now().toIso8601String();
    await db.insert('product_stock_history', {
      'id': historyId,
      'product_id': productId,
      'old_stock': oldStock,
      'new_stock': newStock,
      'qty_changed': qtySold,
      'change_type': changeType,
      'trans_date': transDate,
      'is_synced': 0,
    });

    print("Stock reduced for product $productId: $oldStock → $newStock");
  }

  Future<void> syncOfflineStockHistory() async {
    final online = await isOnline1(); // your existing online check
    if (!online) {
      print("Offline: cannot sync stock history");
      return;
    }

    final db = await localDb.database;

    // 1️⃣ Get all unsynced stock history entries
    final unsyncedHistory = await db.query(
      'product_stock_history',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    for (var entry in unsyncedHistory) {
      try {
        // 2️⃣ Insert into Supabase
        await supabase
            .from('product_stock_history')
            .insert(
              unsyncedHistory
                  .map(
                    (e) => {
                      'product_id': e['product_id'],
                      'old_stock': e['old_stock'],
                      'new_stock': e['new_stock'],
                      'qty_changed': e['qty_changed'],
                      'type': e['type'],
                      'created_at': e['created_at'],
                    },
                  )
                  .toList(),
            );

        // 3️⃣ Mark as synced locally
        await db.update(
          'product_stock_history',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [entry['id']],
        );

        print("Synced stock history for product ${entry['product_id']}");
      } catch (e) {
        print("Failed to sync stock history id ${entry['id']}: $e");
      }
    }

    print("All offline stock history synced!");
  }

  // Get all products from local DB
  Future<List<Map<String, dynamic>>> getLocalProducts() async {
    final db = await localDb.database;
    return await db.query('products');
  }

  //-----------------------LOCAL---------------------------------//
  Future<void> syncSingleProduct(int localId) async {
    final db = await localDb.database;
    final productList = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [localId],
    );
    if (productList.isEmpty) return;

    final p = productList.first;

    try {
      // Convert SQLite fields to proper types
      final name = p['name']?.toString() ?? '';
      final price = (p['price'] as num).toDouble();
      final stock = p['stock'] as int;
      final isPromo = (p['is_promo'] == 1);
      final otherQty = p['other_qty'] as int? ?? 0;

      // Insert into Supabase
      await supabase.from('products').insert({
        'name': name,
        'price': price,
        'stock': stock,
        'is_promo': isPromo,
        'other_qty': otherQty,
      });

      // Mark as synced
      await db.update(
        'products',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [localId],
      );

      print("Product '$name' synced successfully!");
    } catch (e) {
      print("Failed to sync product '${p['name']}': $e");
    }
  }

  Future<int> insertProductOffline({
    required String name,
    required double price,
    required int stock,
    bool isPromo = false,
    int otherQty = 0,
  }) async {
    final db = await localDb.database;

    // ✅ ALWAYS generate a safe, unique client_uuid
    final clientUuid =
        "P_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}";

    return await db.insert('products', {
      'id': generateUniqueId(prefix: "T").hashCode.abs(),
      'name': name,
      'price': price,
      'stock': stock,
      'is_promo': isPromo ? 1 : 0,
      'other_qty': otherQty,
      'is_synced': 0,
      'client_uuid': clientUuid, // ✅ NEVER NULL
    });
  }

  // -----------------------------
  // CHECK INTERNET
  Future<bool> isOnline2() async {
    return await InternetConnectionChecker().hasConnection;
  }






Future<void> updateStockOnline({
  required String clientUuid,
  required int newStock,
}) async {
  await supabase
      .from('products')
      .update({'stock': newStock})
      .eq('client_uuid', clientUuid);
}








  // -----------------------------
  // CORE SYNC FUNCTION
 Future<void> syncOnlineProducts() async {
  final online = await isOnline2();
  if (!online) {
    print("❌ Offline: cannot sync");
    return;
  }

  final db = await localDb.database;

  // ✅ Get latest unsynced product
  final unsynced = await db.query(
    'products',
    where: 'is_synced = ?',
    whereArgs: [0],
    orderBy: 'id DESC', // latest first
    limit: 1,           // only ONE product
  );

  if (unsynced.isEmpty) {
    print("✅ No products to sync");
    return;
  }

  for (final p in unsynced) {
    final clientUuid = p['client_uuid']?.toString();
    if (clientUuid == null || clientUuid.isEmpty) {
      print("⚠️ Skipping product without client_uuid: ${p['name']}");
      continue;
    }

    // 🔹 Safe type casting
    final price = p['price'] is int
        ? (p['price'] as int).toDouble()
        : p['price'] is double
            ? p['price'] as double
            : 0.0;

    final stock = p['stock'] is int ? p['stock'] as int : 0;
    final isPromo = (p['is_promo'] ?? 0) == 1;
    final otherQty = p['other_qty'] is int ? p['other_qty'] as int : 0;
    

    try {
      // 1️⃣ Check if product with same client_uuid exists in Supabase
      final existing = await supabase
          .from('products')
          .select('id')
          .eq('client_uuid', clientUuid)
          .maybeSingle();

      if (existing != null) {
        // 🔁 UPDATE existing product
        await supabase.from('products').update({
          'name': p['name'],
          'price': price,
          'stock': stock,
          'is_promo': isPromo,
          'other_qty': otherQty,
        }).eq('id', existing['id']);
        print("🔁 Updated product '${p['name']}' on Supabase");
      } else {
        // ➕ INSERT new product
        await supabase.from('products').insert({
          'name': p['name'],
          'price': price,
          'stock': stock,
          'is_promo': isPromo,
          'other_qty': otherQty,
          'client_uuid': clientUuid,
        });
        print("➕ Inserted product '${p['name']}' to Supabase");
      }

      // 2️⃣ Mark product as synced locally
      await db.update(
        'products',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [p['id']],
      );

      print("✅ Synced product '${p['name']}' successfully!");
    } catch (e) {
      print("❌ Failed to sync ${p['name']}: $e");
    }
  }

  print("✅ All offline products synced to Supabase");
}


// ------------------- SYNC UNSYNCED PRODUCTS -------------------
  Future<void> syncOfflineProducts() async {
    final online = await isOnline1();
    if (!online) {
      print("Offline: cannot sync to Supabase");
      return;
    }
final unsynced = await localDb.database.then(
  (db) => db.rawQuery('''
    SELECT p.*
    FROM products p
    JOIN product_stock_history h
      ON p.id = h.product_id
    WHERE h.is_synced = 0
    ORDER BY h.created_at DESC
  '''),
);

    //   final unsynced = await localDb.database.then(
    //   (db) => db.query(
    //     'products',
    //     where: 'is_synced = ?',
    //     whereArgs: [0],
    //     orderBy: 'id DESC', // latest product first
    //     limit: 1,           // only ONE product
    //   ),
    // );

    for (var p in unsynced) {
      final clientUuid = p['client_uuid']?.toString();
      if (clientUuid == null || clientUuid.isEmpty) {
        print("Skipping product without client_uuid: ${p['name']}");
        continue; // skip invalid product
      }

      try {
        // 1️⃣ Check if product with same client_uuid exists in Supabase
        final existing = await supabase
            .from('products')
            .select('id')
            .eq('client_uuid', clientUuid)
            .maybeSingle();

        if (existing != null) {
          // 2️⃣ UPDATE existing product
          await supabase
              .from('products')
              .update({
                'name': p['name'],
                'price': p['price'],
                'stock': p['stock'],
                'is_promo': p['is_promo'] == 1,
                'other_qty': p['other_qty'],
              })
              .eq('id', existing['id']);
        } else {
          // 3️⃣ INSERT new product with client_uuid
          await supabase.from('products').insert({
            'name': p['name'],
            'price': p['price'],
            'stock': p['stock'],
            'is_promo': p['is_promo'] == 1,
            'other_qty': p['other_qty'],
            'client_uuid': clientUuid,
          });
        }

        // 4️⃣ Mark as synced locally
        await localDb.database.then(
          (db) => db.update(
            'products',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [p['id']],
          ),
        );

        print("Synced product '${p['name']}' successfully!");
      } catch (e) {
        print("Failed to sync product '${p['name']}': $e");
      }
    }

    print("All offline products synced to Supabase");
  }


  // -----------------------------
    // -----------------------------
      // -----------------------------












  // -----------------------------
  // GET ALL PRODUCTS (LOCAL VIEW)
  Future<List<Productclass>> getAllProducts2() async {
    final db = await localDb.database;
    final res = await db.query('products', orderBy: 'name ASC');
    return res.map((e) => Productclass.fromMap(e)).toList();
  }

  // GET ALL PRODUCTS (ONLINE VIEW)
Future<List<Productclass>> getAllProductsOnline() async {
  try {
    final data = await supabase
        .from('products')
        .select()
        .order('name', ascending: true);

    return (data as List)
        .map((e) => Productclass.fromMap(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    print("❌ Failed to fetch online products: $e");
    return [];
  }
}


  

  Future<bool> isOnline1() async {
    // Check if device is online
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Fetch all products from Supabase and save locally
  Future<void> syncAllTables() async {
    final online = await isOnline1();
    if (!online) {
      print("Offline: dili maka-sync sa Supabase");
      return;
    }

    try {
      // ----------------- PRODUCTS -----------------
      final supaProducts = await supabase.from('products').select();
      for (var p in supaProducts) {
        await localDb.insertProduct(
          id: p['id'] as int,
          name: p['name'] as String,
          price: (p['price'] as num).toDouble(),
          stock: p['stock'] as int,
          isPromo: p['is_promo'] as bool? ?? false,
          otherQty: p['other_qty'] as int? ?? 0,
        );
      }

      // ----------------- TRANSACTIONS -----------------
      final supaTransactions = await supabase.from('transactions').select();
      for (var t in supaTransactions) {
        await localDb.insertTransaction(
          id: t['id'] as int,
          total: (t['total'] as num).toDouble(),
          cash: (t['cash'] as num).toDouble(),
          change: (t['change'] as num).toDouble(),
          createdAt: t['created_at'] as String?,
        );
      }

      // ----------------- TRANSACTION ITEMS -----------------
      final supaItems = await supabase.from('transaction_items').select();
      for (var item in supaItems) {
        await localDb.insertTransactionItem(
          id: item['id'] as int,
          transactionId: item['transaction_id'] as int,
          productId: item['product_id'] as int,
          productName: item['product_name'] as String,
          qty: item['qty'] as int,
          price: (item['price'] as num).toDouble(),
          isPromo: item['is_promo'] as bool? ?? false,
          otherQty: item['other_qty'] as int? ?? 0,
        );
      }

      print("Sync all tables successful!");
    } catch (e) {
      print("Error during sync: $e");
    }
  }

  // Kuhaon tanan products gikan sa 'products' table
  Future<List<Productclass>> fetchProducts() async {
    final data = await supabase
        .from('products')
        .select()
        .order('name'); // optional: i-sort by name

    // Convert sa data ngadto sa Productclass object
    return (data as List<dynamic>)
        .map((e) => Productclass.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // CREATE
  Future<void> addProduct(
    String name,
    double price,
    int stock,
    bool isPromo,
    int otherQty,
  ) async {
    await supabase.from('products').insert({
      'name': name,
      'price': price,
      'stock': stock,
      'is_promo': isPromo,
      'other_qty': otherQty,
    });
  }

  // READ
  Future<List<Map<String, dynamic>>> getProducts() async {
    final data = await supabase.from('products').select();
    return List<Map<String, dynamic>>.from(data);
  }

  // UPDATE
  Future<void> updateStock(int id, int newStock) async {
    await supabase.from('products').update({'stock': newStock}).eq('id', id);
  }

  // DELETE
  Future<void> deleteProduct(int id) async {
    await supabase.from('products').delete().eq('id', id);
  }

  Future<void> syncOfflineTransactions() async {
    final online = await isOnline1();
    if (!online) return;

    final unsynced = await localDb
        .getUnsyncedTransactions(); // returns only is_synced=0

    for (var trx in unsynced) {
      try {
        // Check if transaction already exists online
        final existing = await supabase
            .from('transactions')
            .select('id')
            .eq('id', trx['id'])
            .maybeSingle();

        if (existing == null) {
          // Insert transaction online
          await supabase.from('transactions').insert({
            'id': trx['id'],
            'total': trx['total'],
            'cash': trx['cash'],
            'change': trx['change'],
            'created_at': trx['created_at'],
          });

          // Insert transaction items
          final items = await localDb.getItemsForTransaction(trx['id']);
          for (var item in items) {
            await supabase.from('transaction_items').insert({
              'id': item['id'],
              'transaction_id': trx['id'],
              'product_id': item['product_id'],
              'product_name': item['product_name'],
              'qty': item['qty'],
              'price': item['price'],
              'is_promo': item['is_promo'] == 1,
              'other_qty': item['other_qty'],
            });

            // Mark item as synced locally
            await localDb.markItemSynced(item['id']);
          }

          // Mark transaction as synced locally
          await localDb.markTransactionSynced(trx['id']);
        }
      } catch (e) {
        print("Failed to sync transaction ${trx['id']}: $e");
      }
    }
  }

  Future<void> syncSingleProductOnline(int productId) async {
  final db = await localDb.database;

  // ✅ Get product by id
  final pList = await db.query(
    'products',
    where: 'id = ?',
    whereArgs: [productId],
  );

  if (pList.isEmpty) return;
  final p = pList.first;

  final clientUuid = p['client_uuid']?.toString();
  if (clientUuid == null || clientUuid.isEmpty) return;

  final price = (p['price'] is int) ? (p['price'] as int).toDouble() : (p['price'] as double);
  final stock = p['stock'] as int;
  final isPromo = (p['is_promo'] ?? 0) == 1;
  final otherQty = p['other_qty'] as int;

  try {
    final existing = await supabase
        .from('products')
        .select('id')
        .eq('client_uuid', clientUuid)
        .maybeSingle();

    if (existing != null) {
      // Update only
      await supabase.from('products').update({
        'name': p['name'],
        'price': price,
        'stock': stock,
        'is_promo': isPromo,
        'other_qty': otherQty,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existing['id']);
      print("🔁 Updated product '${p['name']}' on Supabase");
    } else {
      // Insert new
      await supabase.from('products').insert({
        'name': p['name'],
        'price': price,
        'stock': stock,
        'is_promo': isPromo,
        'other_qty': otherQty,
        'client_uuid': clientUuid,
        'updated_at': DateTime.now().toIso8601String(),
      });
      print("➕ Inserted product '${p['name']}' to Supabase");
    }

    // Mark as synced locally
    await db.update(
      'products',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [p['id']],
    );
  } catch (e) {
    print("❌ Failed to sync ${p['name']}: $e");
  }
}

}
