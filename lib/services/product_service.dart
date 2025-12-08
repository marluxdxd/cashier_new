import 'dart:io';

import 'package:cashier/class/productclass.dart';
import 'package:cashier/database/local_db.dart';

import 'package:cashier/database/supabase.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ProductService {
  final supabase = SupabaseConfig.supabase;
  final localDb = LocalDatabase();

  Future<bool> isOnline() async {
    var connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }

  //LOCAL ------
  // Check if device is online
  Future<bool> isOnline1() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Fetch all products from Supabase and save locally
  Future<void> syncProducts() async {
    final online = await isOnline1();
    if (!online) {
      print("Offline: dili maka-sync sa Supabase");
      return;
    }

    try {
      // 1️⃣ Fetch all products from Supabase
      final supaProducts = await supabase.from('products').select();
      print("Supabase fetched: $supaProducts");

      if (supaProducts.isEmpty) {
        print("Walay data sa Supabase");
        return;
      }

      // 2️⃣ Optional: Clear existing local DB
      final localProducts = await localDb.getProducts();
      for (var p in localProducts) {
        await localDb.deleteProduct(p['id'] as int);
      }

      // 3️⃣ Insert all products into local SQLite
      for (var p in supaProducts) {
        try {
          await localDb.insertProduct(
            id: p['id'] as int,
            name: p['name'] as String,
            price: (p['price'] as num).toDouble(),
            stock: p['stock'] as int,
            isPromo: p['is_promo'] as bool? ?? false,
            otherQty: p['other_qty'] as int? ?? 0,
          );
        } catch (e) {
          print("Insert error: $e for product $p");
        }
      }

      // 4️⃣ Verify local DB
      final savedProducts = await localDb.getProducts();
      if (savedProducts.isNotEmpty) {
        print("Sync successful! Na-save sa local DB:");
        for (var p in savedProducts) {
          print(p['name']);
        }
      } else {
        print("Sync failed: Wala na-save sa local DB");
      }
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
}
