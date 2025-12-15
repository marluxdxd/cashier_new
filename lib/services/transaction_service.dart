import 'dart:io';
import 'package:cashier/class/product_offline.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; // For formatted timestamp

final uuid = Uuid();

String generateUuid() {
  return uuid.v4(); // e.g., 'f47ac10b-58cc-4372-a567-0e02b2c3d479'
}

class TransactionService {
  final supabase = Supabase.instance.client;
  final supabase2 = SupabaseConfig.supabase;
  final localDb = LocalDatabase();

  //---------------- PHT Timestamp Helper ----------------
  /// Returns ISO8601 Philippine timestamp (UTC+8)
  String getPhilippineTimestamp() {
    final nowUtc = DateTime.now().toUtc();
    final philippineTime = nowUtc.add(Duration(hours: 8));
    return philippineTime.toIso8601String();
  }

  /// Returns formatted Philippine timestamp (yyyy-MM-dd HH:mm:ss)
  String getPhilippineTimestampFormatted() {
    final nowUtc = DateTime.now().toUtc();
    final philippineTime = nowUtc.add(Duration(hours: 8));
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(philippineTime);
  }

  //---------------- Offline Insert ----------------
  Future<String> insertTransactionOffline({
    required double total,
    required double cash,
    required double change,
    required List<ProductOffline> items,
  }) async {
    final db = await localDb.database;

    // 1️⃣ Save main transaction
    final transactionId = generateUuid();
    await db.insert('transactions', {
      'id': transactionId,
      'total': total,
      'cash': cash,
      'change': change,
      'created_at': getPhilippineTimestamp(), // PHT timestamp
      'is_synced': 0,
    });

    // 2️⃣ Save each transaction item
    for (var item in items) {
      final itemId = generateUuid();
      await db.insert('transaction_items', {
        'id': itemId,
        'transaction_id': transactionId,
        'product_id': item.productId,
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

  //---------------- Check Internet ----------------
  Future<bool> isOnline2() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  //---------------- Sync Offline Transactions ----------------
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
        // Insert into Supabase
        final result = await supabase.from('transactions').insert({
          'total': t['total'],
          'cash': t['cash'],
          'change': t['change'],
          'created_at': t['created_at'], // Use local PHT timestamp
        }).select();

        final newTransactionId = result[0]['id'];

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

  //---------------- Validation & Calculation ----------------
  bool isCashSufficient(double total, double cash) {
    return cash >= total;
  }

  double calculateChange(double total, double cash) {
    return cash - total;
  }

  //---------------- Save Transaction Online ----------------
  Future<int> saveTransaction({
    required double total,
    required double cash,
    required double change,
  }) async {
    final response = await supabase
        .from('transactions')
        .insert({
          'total': total,
          'cash': cash,
          'change': change,
          'created_at': getPhilippineTimestamp(), // PHT timestamp
        })
        .select('id')
        .single();

    return response['id'];
  }

  //---------------- Save Transaction Item Online ----------------
  Future<void> saveTransactionItem({
    required int transactionId,
    required dynamic product,
    required int qty,
    required bool isPromo,
    required int otherQty,
  }) async {
    await supabase.from('transaction_items').insert({
      'transaction_id': transactionId,
      'product_id': product.id,
      'product_name': product.name,
      'qty': qty,
      'price': product.price,
      'is_promo': isPromo,
      'other_qty': otherQty,
    });
  }

  //---------------- Update Stock ----------------
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
