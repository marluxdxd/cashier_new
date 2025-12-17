import 'dart:io';
import 'package:cashier/class/productclass.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:math';
int generateUniqueId() {
  // Combine milliseconds + random 4-digit number
  return DateTime.now().millisecondsSinceEpoch + Random().nextInt(90);
}


class ProductService {
  final supabase = SupabaseConfig.supabase;
  final localDb = LocalDatabase();

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
      );
    }

    return (data as List<dynamic>)
        .map((e) => Productclass.fromMap(e as Map<String, dynamic>))
        .toList();
  } else {
    // Fetch from local DB
    final localData = await localDb.getProducts();
    return localData
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

    final int localId = generateUniqueId();
    final local = await getLocalProducts();
    print("LOCAL PRODUCTS: $local");
    return await db.insert('products', {
      'id': localId, // ✅ REQUIRED
      'name': name,
      'price': price,
      'stock': stock,
      'is_promo': isPromo ? 1 : 0,
      'other_qty': otherQty,
      'is_synced': 0,
    });
  }

  // ------------------- SYNC UNSYNCED PRODUCTS -------------------
  Future<void> syncOfflineProducts() async {
    final online = await isOnline1();
    if (!online) {
      print("Offline: dili maka-sync sa Supabase");
      return;
    }

    final unsynced = await localDb.database.then(
      (db) => db.query('products', where: 'is_synced = ?', whereArgs: [0]),
    );

    for (var p in unsynced) {
      try {
        final existing = await supabase
            .from('products')
            .select('id')
            .eq('name', p['name'] as String)
            .maybeSingle();

        if (existing != null) {
          // Update
          await supabase
              .from('products')
              .update({
                'price': p['price'],
                'stock': p['stock'],
                'is_promo': p['is_promo'] == 1,
                'other_qty': p['other_qty'],
              })
              .eq('id', existing['id']);
        } else {
          // Insert
          await supabase.from('products').insert({
            'name': p['name'],
            'price': p['price'],
            'stock': p['stock'],
            'is_promo': p['is_promo'] == 1,
            'other_qty': p['other_qty'],
          });
        }

        // Mark as synced locally
        await localDb.database.then(
          (db) => db.update(
            'products',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [p['id']],
          ),
        );
      } catch (e) {
        print("Failed to sync product ${p['name']}: $e");
      }
    }

    print("Offline products synced to Supabase");
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

  final unsynced = await localDb.getUnsyncedTransactions(); // returns only is_synced=0

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

}
