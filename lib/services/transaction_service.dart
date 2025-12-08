import 'dart:io';

import 'package:cashier/class/product_offline.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
//-----------MANUAL--------------------------
// class TransactionService {
//   /// Calculate change given total and cash
//   double calculateChange(double total, double cash) {
//     return cash - total;
//   }

//   /// Get current timestamp formatted as MM-dd-yyyy HH:mm:ss
//   String getCurrentTimestamp() {
//     DateTime now = DateTime.now();
//     return DateFormat('MM-dd-yyyy HH:mm:ss').format(now);
//   }

//   /// Validate if cash is enough
//   bool isCashSufficient(double total, double cash) {
//     return cash >= total;
//   }
// }
final uuid = Uuid();

String generateUuid() {
  return uuid.v4(); // e.g., 'f47ac10b-58cc-4372-a567-0e02b2c3d479'
}

class TransactionService {
  final supabase = Supabase.instance.client;
  final supabase2 = SupabaseConfig.supabase;
  final localDb = LocalDatabase();

  Future<String> insertTransactionOffline({
  required double total,
  required double cash,
  required double change,
  required List<ProductOffline> items,
}) async {
  final db = await localDb.database;

  // 1️⃣ Save main transaction
  final transactionId = generateUuid(); // UUID for transaction
  await db.insert('transactions', {
    'id': transactionId,
    'total': total,
    'cash': cash,
    'change': change,
    'created_at': DateTime.now().toIso8601String(),
    'is_synced': 0,
  });

  // 2️⃣ Save each transaction item
  for (var item in items) {
    final itemId = generateUuid(); // UUID for each item
    await db.insert('transaction_items', {
      'id': itemId,
      'transaction_id': transactionId,
      'product_id': item.productId, // keep numeric for product, or change to UUID if needed
      'product_name': item.productName,
      'qty': item.qty,
      'price': item.price,
      'is_promo': item.isPromo ? 1 : 0,
      'other_qty': item.otherQty,
      'is_synced': 0,
    });
  }

  return transactionId;
}


  //--------------CHECK INTERNET-------------------------------
  Future<bool> isOnline2() async {
    // Check if device is online
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ------------------- SYNC UNSYNCED PRODUCTS -------------------
Future<void> syncOfflineTransactions() async {
  final online = await isOnline2();
  if (!online) return;

  final db = await localDb.database;

  final unsyncedTransactions = await db.query(
    'transactions',
    where: 'is_synced = ?',
    whereArgs: [0],
  );

  for (var t in unsyncedTransactions) {
    try {
      // Insert sa Supabase
      final result = await supabase.from('transactions').insert({
        'total': t['total'],
        'cash': t['cash'],
        'change': t['change'],
        'created_at': t['created_at'],
      }).select(); // returns inserted row

      final newTransactionId = result[0]['id']; // Supabase ID

      // Sync transaction_items
      final items = await db.query(
        'transaction_items',
        where: 'transaction_id = ? AND is_synced = ?',
        whereArgs: [t['id'], 0],
      );

      for (var item in items) {
        await supabase.from('transaction_items').insert({
          'transaction_id': newTransactionId,
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'qty': item['qty'],
          'price': item['price'],
          'is_promo': item['is_promo'] == 1,
          'other_qty': item['other_qty'],
        });

        // Mark item as synced locally
        await db.update(
          'transaction_items',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }

      // Mark transaction as synced locally
      await db.update(
        'transactions',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [t['id']],
      );

      print("Transaction ${t['id']} synced → Supabase ID: $newTransactionId");

    } catch (e) {
      print("Failed to sync transaction ${t['id']}: $e");
    }
  }

  print("All offline transactions synced!");
}

  //---------SUPABASE-----------------
  // ------------------------------
  // VALIDATION + CALCULATIONS
  // ------------------------------

  bool isCashSufficient(double total, double cash) {
    return cash >= total;
  }

  double calculateChange(double total, double cash) {
    return cash - total;
  }

  // int minusQty(QT){
  //   return
  // }

  // DATE & TIME
  String getCurrentTimestamp() {
    return DateTime.now().toIso8601String();
  }

  // ------------------------------
  // SAVE TRANSACTION (HEADER)
  // ------------------------------

  Future<int> saveTransaction({
    required double total,
    required double cash,
    required double change,
  }) async {
    final response = await supabase
        .from('transactions')
        .insert({'total': total, 'cash': cash, 'change': change})
        .select('id')
        .single();

    return response['id'];
  }

  // ------------------------------
  // SAVE TRANSACTION ITEM (DETAILS)
  // ------------------------------

  Future<void> saveTransactionItem({
    required int transactionId,
    required dynamic product,
    required int qty,
    required bool isPromo,
    required int otherQty,
  }) async {
    await supabase.from('transaction_items').insert({
      'transaction_id': transactionId, // link sa main transaction
      'product_id': product.id, // unsang product ni
      'product_name': product.name, // record sa name sa time sa sale
      'qty': qty,
      'price': product.price,
      'is_promo': isPromo, // price sa time sa sale
      'other_qty': otherQty,
    });
  }

  //---------------- I-update ang Stock sa Product
  Future<void> updateStock({
    required int productId,
    required int newStock,
  }) async {
    await supabase
        .from('products')
        .update({'stock': newStock})
        .eq('id', productId);
  }
}
