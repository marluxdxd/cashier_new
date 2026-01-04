import 'dart:async';
import 'dart:io';
import 'package:cashier/class/productclass.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';
import 'package:cashier/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:uuid/uuid.dart';

String generateUniqueId({String prefix = "S"}) {
  return "$prefix${DateTime.now().millisecondsSinceEpoch}";
}

class ProductService {
  final supabase = SupabaseConfig.supabase;
  final localDb = LocalDatabase();
  final uuidGen = Uuid();
  late final Connectivity _connectivity;
  late final StreamSubscription _connectivitySub;

  void listenToConnectivity(VoidCallback onOnline) {
    print("📡 Connectivity listener started");

    _connectivity = Connectivity();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((
      result,
    ) async {
      print("📡 Connectivity changed: $result");

      if (result != ConnectivityResult.none) {
        final online = await isOnline1();
        print("🌐 Internet status: $online");

        if (online) {
          print("🔄 Triggering sync...");
          await syncOfflineProducts();
          await syncOfflineStockHistory();
          await syncOfflineTransactions();
          onOnline();
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
          retailPrice: (p['retail_price'] as num).toDouble(),
          costPrice: (p['cost_price'] as num).toDouble(),
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
              retailPrice: e['retail_price'],
              costPrice: e['cost_price'],
              stock: e['stock'],
              isPromo: e['is_promo'] == 1,
              productClientUuid: e['client_uuid'] as String,
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
    print("📦 reduceStock START | productId=$productId qty=$qtySold");
    final db = await localDb.database;

    // Get current stock
    final productList = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (productList.isEmpty) {
      print("❌ Product not found locally");
      return;
    }

    final product = productList.first;
    final int oldStock = product['stock'] as int;
    final int newStock = oldStock - qtySold;

    print("➡️ oldStock=$oldStock newStock=$newStock");

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
      'product_client_uuid': product['client_uuid'], // 🔑 KEY FIX
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
    print("📦 syncOfflineStockHistory START");
    final db = await LocalDatabase().database;

    // // 🔹 DEBUG: Print all local stock history
    // final allHistory = await db.query('product_stock_history');
    // print("📋 LOCAL STOCK HISTORY (ALL ROWS):");
    // for (var row in allHistory) {
    //   print(row);
    // }

    // 1️⃣ Get all unsynced stock history
    final unsyncedHistory = await db.query(
      'product_stock_history',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    print("➡️ Unsynced history count: ${unsyncedHistory.length}");

    if (unsyncedHistory.isEmpty) {
      print("✅ No stock history to sync");
      return;
    }

    for (var entry in unsyncedHistory) {
      try {
        // 2️⃣ Ensure product_client_uuid exists
        String clientUuid = entry['product_client_uuid']?.toString() ?? '';
        if (clientUuid.isEmpty) {
          print(
            "❌ Stock history id ${entry['id']} has no product_client_uuid. Skipping.",
          );
          continue;
        }

        // 3️⃣ Fetch local product by client_uuid
        final productList = await db.query(
          'products',
          where: 'client_uuid = ?',
          whereArgs: [clientUuid],
        );

        if (productList.isEmpty) {
          print(
            "⚠️ Product not found locally for stock history id ${entry['id']}. Skipping.",
          );
          continue;
        }

        final product = productList.first;
        final productName = product['name']?.toString() ?? 'unknown';

        // 4️⃣ Ensure product exists in Supabase
        final supaProduct = await supabase
            .from('products')
            .select('id')
            .eq('client_uuid', clientUuid)
            .maybeSingle();

        int supaProductId;

        if (supaProduct != null) {
          supaProductId = supaProduct['id'] as int;
        } else {
          // Insert missing product
          final inserted = await supabase
              .from('products')
              .insert({
                'name': productName,
                'cost_price': product['cost_price'] ?? 0.0,
                'retail_price': product['retail_price'] ?? 0.0,
                'stock': product['stock'] ?? 0,
                'is_promo': product['is_promo'] == 1,
                'other_qty': product['other_qty'] ?? 0,
                'client_uuid': clientUuid,
              })
              .select('id')
              .maybeSingle();

          if (inserted == null || inserted['id'] == null) {
            print(
              "❌ Failed to insert product '$productName'. Skipping stock history.",
            );
            continue;
          }

          supaProductId = inserted['id'] as int;
          print("➕ Inserted missing product '$productName' to Supabase");
        }

        print("🔍 SYNCING STOCK HISTORY ENTRY ID: ${entry['id']}");
        print("➡️ supaProductId: $supaProductId");
        print("➡️ clientUuid: $clientUuid");

        // 5️⃣ Insert stock history into Supabase including product_name
        try {
          await supabase.from('product_stock_history').insert({
            'product_id': supaProductId,
            'product_name': productName, // ✅ Add product name
            'old_stock': entry['old_stock'],
            'new_stock': entry['new_stock'],
            'qty_changed': entry['qty_changed'],
            'change_type':
                entry['type']?.toString() ??
                'adjust', // <-- must match Supabase
            'trans_date':
                entry['trans_date']?.toString() ??
                DateTime.now().toIso8601String(),
            'created_at':
                entry['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'product_client_uuid': clientUuid,
          });
        } catch (e) {
          print(
            "❌ Failed to insert stock history id ${entry['id']} to Supabase: $e",
          );
          continue;
        }

        // 6️⃣ Mark stock history as synced locally
        await db.update(
          'product_stock_history',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [entry['id']],
        );

        print("✅ Synced stock history id ${entry['id']}");
      } catch (e) {
        print("❌ Failed to sync stock history id ${entry['id']}: $e");
      }
    }

    print("🎉 All offline stock history synced!");
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
    final clientUuid = p['client_uuid']?.toString();

    if (clientUuid == null || clientUuid.isEmpty) {
      print("⚠️ Product '${p['name']}' has no client_uuid, skipping sync.");
      return;
    }

    try {
      // Check if product already exists in Supabase
      final existing = await supabase
          .from('products')
          .select('id')
          .eq('client_uuid', clientUuid)
          .maybeSingle();

      final name = p['name']?.toString() ?? '';
      final costPrice = (p['cost_price'] as num).toDouble();
      final retailPrice = (p['retail_price'] as num).toDouble();
      final stock = p['stock'] as int;
      final isPromo = (p['is_promo'] == 1);
      final otherQty = p['other_qty'] as int? ?? 0;

      if (existing != null) {
        // 🔁 Update existing product
        await supabase
            .from('products')
            .update({
              'name': name,

              'cost_price': costPrice,
              'retail_price': retailPrice,
              'stock': stock,
              'is_promo': isPromo,
              'other_qty': otherQty,
            })
            .eq('id', existing['id']);
        print("🔁 Updated product '$name' on Supabase");
      } else {
        // ➕ Insert new product
        await supabase.from('products').insert({
          'name': name,
          'cost_price': costPrice,
          'retail_price': retailPrice,
          'stock': stock,
          'is_promo': isPromo,
          'other_qty': otherQty,
          'client_uuid': clientUuid,
        });
        print("➕ Inserted product '$name' to Supabase");
      }

      // Mark as synced locally
      await db.update(
        'products',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      print("❌ Failed to sync product '${p['name']}': $e");
    }
  }

  Future<int> insertProductOffline({
    required String name,
    required double costPrice,
    required double retailPrice,
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
      'cost_price': costPrice,
      'retail_price': retailPrice,
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
      limit: 1, // only ONE product
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

      final retailPrice = p['retail_price'] is int
          ? (p['retail_price'] as int).toDouble()
          : p['retail_price'] is double
          ? p['retail_price'] as double
          : 0.0;
      final costPrice = p['cost_price'] is int
          ? (p['cost_price'] as int).toDouble()
          : p['cost_price'] is double
          ? p['cost_price'] as double
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
          await supabase
              .from('products')
              .update({
                'name': p['name'],
                'cost_price': costPrice,
                'retail_price': retailPrice,
                'stock': stock,
                'is_promo': isPromo,
                'other_qty': otherQty,
              })
              .eq('id', existing['id']);
          print("🔁 Updated product '${p['name']}' on Supabase");
        } else {
          // ➕ INSERT new product
          await supabase.from('products').insert({
            'name': p['name'],
            'cost_price': costPrice,
            'retail_price': retailPrice,
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
                'retail_price': p['retail_price'],
                'cost_price': p['cost_price'],
                'stock': p['stock'],
                'is_promo': p['is_promo'] == 1,
                'other_qty': p['other_qty'],
              })
              .eq('id', existing['id']);
        } else {
          // 3️⃣ INSERT new product with client_uuid
          await supabase.from('products').insert({
            'name': p['name'],
            'retail_price': p['retail_price'],
            'cost_price': p['cost_price'],
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
        await localDb.upsertProductByClientUuid(
          clientUuid: p['client_uuid'],
          name: p['name'],
          cost_price: (p['cost_price'] as num).toDouble(),
          retail_price: (p['retail_price'] as num).toDouble(),
          stock: p['stock'] as int,
          isPromo: p['is_promo'] as bool? ?? false,
          otherQty: p['other_qty'] as int? ?? 0,
        );
      }

      // ----------------- TRANSACTIONS -----------------
      final supaTransactions = await supabase.from('transactions').select();
      for (var t in supaTransactions) {
        await localDb.insertTransaction(
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
          transactionId: item['transaction_id'] as int,
          productId: item['product_id'] as int,
          productName: item['product_name'] as String,
          qty: item['qty'] as int,
          costPrice: (item['cost_price'] as num).toDouble(),
          retailPrice: (item['retail_price'] as num).toDouble(),
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
    double costPrice,
    double retailPrice,
    int stock,
    bool isPromo,
    int otherQty,
  ) async {
    final clientUuid =
        "P_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}";

    await supabase.from('products').insert({
      'name': name,
      'cost_price': costPrice,
      'retail_price': retailPrice,
      'stock': stock,
      'is_promo': isPromo,
      'other_qty': otherQty,
      'client_uuid': clientUuid,
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

    final unsynced = await localDb.getUnsyncedTransactions(); // is_synced = 0

    for (var trx in unsynced) {
      try {
        // ---------------- 1️⃣ Check or insert transaction ----------------
        final existingTrx = await supabase
            .from('transactions')
            .select('id')
            .eq('offline_id', trx['id'])
            .maybeSingle();

        int supaTransactionId;

        if (existingTrx == null) {
          // Insert new transaction
          final inserted = await supabase
              .from('transactions')
              .insert({
                'total': trx['total'],
                'cash': trx['cash'],
                'change': trx['change'],
                'created_at': trx['created_at'],
                'offline_id': trx['id'],
                'client_uuid':
                    trx['client_uuid'] ?? generateUniqueId(prefix: "T"),
              })
              .select('id')
              .maybeSingle();

          if (inserted == null || inserted['id'] == null) {
            print("❌ Failed to insert transaction ${trx['id']}");
            continue;
          }

          supaTransactionId = inserted['id'] as int;
        } else {
          supaTransactionId = existingTrx['id'] as int;
        }

        // ---------------- 2️⃣ Insert transaction items ----------------
        final localTransactionId = trx['id'];
        final supabaseTransactionId = trx['supabase_id'];

        final items = await localDb.getItemsForTransaction(localTransactionId);

        for (var item in items) {
          try {
            await supabase.from('transaction_items').upsert(
              {
                'transaction_id': supaTransactionId,
                'product_id': item['product_id'],
                'qty': item['qty'],
                'cost_price': item['cost_price'],
                'retail_price': item['retail_price'],
                'product_name': item['product_name'],
                'is_promo': item['is_promo'] == 1,
                'other_qty': item['other_qty'],
                'product_client_uuid':
                    item['product_client_uuid'] ??
                    generateUniqueId(prefix: "P"),
              },
              onConflict: 'product_client_uuid, transaction_id, product_id',
            ); // pass as string, not list

            // Mark item as synced locally
            await localDb.markItemSynced(item['id']);
          } catch (e) {
            print("❌ Failed to sync item ${item['id']}: $e");
          }
        }

        // ---------------- 3️⃣ Mark transaction as synced ----------------
        await localDb.markTransactionSynced(trx['id']);
        print("✅ Transaction ${trx['id']} and items synced successfully!");
      } catch (e) {
        print("❌ Failed to sync transaction ${trx['id']}: $e");
      }
    }

    print("✅ All offline transactions synced!");
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

    final retailPrice = (p['retail_price'] is int)
        ? (p['retail_price'] as int).toDouble()
        : (p['retail_price'] as double);
    final costPrice = (p['cost_price'] is int)
        ? (p['cost_price'] as int).toDouble()
        : (p['cost_price'] as double);

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
        await supabase
            .from('products')
            .update({
              'name': p['name'],
              'cost_price': costPrice,
              'retail_price': retailPrice,
              'stock': stock,
              'is_promo': isPromo,
              'other_qty': otherQty,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
        print("🔁 Updated product '${p['name']}' on Supabase");
      } else {
        // Insert new
        await supabase.from('products').insert({
          'name': p['name'],
          'cost_price': costPrice,
          'retail_price': retailPrice,
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

  Future<int> insertTransactionItemOffline({
    required int transactionId,
    required Productclass product,
    required int qty,
    required bool isPromo,
    required int otherQty,
  }) async {
    final id = generateUniqueId(prefix: "TI").hashCode.abs();

    return await localDb.insertTransactionItem(
      transactionId: transactionId,
      productId: product.id,
      productName: product.name,
      qty: qty,
      costPrice: product.costPrice,
      retailPrice: product.retailPrice,

      isPromo: isPromo,
      otherQty: otherQty,
    );
  }

  Future<void> syncOfflineTransactionItems() async {
    final online = await InternetConnectionChecker().hasConnection;
    if (!online) return;

    final db = await localDb.database;

    // Kuhaon tanan unsynced transaction items (is_synced = 0)
    final unsyncedItems = await db.query(
      'transaction_items',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    for (var item in unsyncedItems) {
      try {
        // Siguraduhon ang casting sa tanan fields
        final int localId = item['id'] is int
            ? item['id'] as int
            : int.tryParse(item['id'].toString()) ?? 0;

        final int trxId = item['transaction_id'] is int
            ? item['transaction_id'] as int
            : int.tryParse(item['transaction_id'].toString()) ?? 0;

        final int productId = item['product_id'] is int
            ? item['product_id'] as int
            : int.tryParse(item['product_id'].toString()) ?? 0;

        final String productName = item['product_name']?.toString() ?? '';
        final int qty = item['qty'] is int
            ? item['qty'] as int
            : int.tryParse(item['qty'].toString()) ?? 0;

        final double costPrice = item['cost_price'] is int
            ? (item['cost_price'] as int).toDouble()
            : item['cost_price'] is double
            ? item['cost_price'] as double
            : 0.0;
        final double retailPrice = item['retail_price'] is int
            ? (item['retail_price'] as int).toDouble()
            : item['retail_price'] is double
            ? item['retail_price'] as double
            : 0.0;

        final bool isPromo = (item['is_promo'] ?? 0) == 1;
        final int otherQty = item['other_qty'] is int
            ? item['other_qty'] as int
            : int.tryParse(item['other_qty']?.toString() ?? '0') ?? 0;

        final String productClientUuid =
            item['product_client_uuid']?.toString() ??
            "P_${DateTime.now().millisecondsSinceEpoch}";

        // 1️⃣ Ensure product exists in Supabase
        final existingProduct = await supabase
            .from('products')
            .select('id, stock')
            .eq('client_uuid', productClientUuid)
            .maybeSingle();

        int supaProductId;
        int supaProductStock = 0;

        if (existingProduct != null) {
          supaProductId = existingProduct['id'] as int;
          supaProductStock = existingProduct['stock'] as int? ?? 0;
        } else {
          // Insert missing product
          final insertedProduct = await supabase
              .from('products')
              .insert({
                'name': productName,
                'cost_price': costPrice,
                'retail_price': retailPrice,
                'stock': otherQty + qty, // assume initial stock
                'is_promo': isPromo,
                'other_qty': otherQty,
                'client_uuid': productClientUuid,
              })
              .select('id')
              .maybeSingle();

          if (insertedProduct == null || insertedProduct['id'] == null) {
            print(
              "❌ Failed to insert missing product '$productName'. Skipping item.",
            );
            continue;
          }

          supaProductId = insertedProduct['id'] as int;
          print("➕ Inserted missing product '$productName' to Supabase");
        }

        // 2️⃣ Insert transaction item using Supabase product ID
        final existingItem = await supabase
            .from('transaction_items')
            .select('id')
            .eq('product_client_uuid', productClientUuid)
            .eq('transaction_id', trxId)
            .maybeSingle();

        if (existingItem != null) {
          // Update existing item
          await supabase
              .from('transaction_items')
              .update({
                'transaction_id': trxId,
                'product_id': supaProductId,
                'product_name': productName,
                'qty': qty,
                'is_promo': isPromo,
                'other_qty': otherQty,
              })
              .eq('id', existingItem['id']);
        } else {
          // Insert new item
          await supabase.from('transaction_items').insert({
            'transaction_id': trxId,
            'product_id': supaProductId,
            'product_name': productName,
            'qty': qty,
            'cost_price': costPrice,
            'retail_price': retailPrice,
            'is_promo': isPromo,
            'other_qty': otherQty,
            'product_client_uuid': productClientUuid,
          });
        }

        // 3️⃣ Mark item as synced locally
        await db.update(
          'transaction_items',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [localId],
        );

        print("✅ Synced transaction item id $localId successfully!");
      } catch (e) {
        print("❌ Failed to sync transaction item id ${item['id']}: $e");
      }
    }

    print("🎉 All offline transaction items synced!");
  }

  Future<bool> productNameExists(String name) async {
    final db = await localDb.database;

    final result = await db.query(
      'products', // change table name if needed
      where: 'LOWER(name) = ?',
      whereArgs: [name.toLowerCase()],
    );

    return result.isNotEmpty;
  }
}
