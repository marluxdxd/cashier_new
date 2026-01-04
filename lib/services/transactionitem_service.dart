import 'dart:io';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';
import 'package:cashier/class/product_offline.dart';

class TransactionItemService {
  final localDb = LocalDatabase();
  final supabase = SupabaseConfig.supabase;

  // Check if device is online
  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ------------------- INSERT TRANSACTION OFFLINE -------------------
  Future<int> insertTransactionItemOffline({
    required double total,
    required double cash,
    required double change,
    required List<ProductOffline> items,
  }) async {
    final db = await localDb.database;

    // Insert transaction header
    final transactionId = await db.insert('transactions', {
      'total': total,
      'cash': cash,
      'change': change,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });

    // Insert transaction items
    for (var item in items) {
      await db.insert('transaction_items', {
        'transaction_id': transactionId,
        'product_id': item.productId,
        'product_name': item.productName,
        'qty': item.qty,
        'cost_price': item.costPrice,
        'retail_price': item.retailPrice,
        'is_promo': item.isPromo ? 1 : 0,
        'other_qty': item.otherQty,
        'is_synced': 0,
        'product_client_uuid': item.productClientUuid
      });
    }

    return transactionId;
  }

  // ------------------- GET TRANSACTIONS OFFLINE -------------------
  Future<List<Map<String, dynamic>>> getTransactionsOffline() async {
    final db = await localDb.database;
    return await db.query('transactions');
  }

  Future<List<Map<String, dynamic>>> getTransactionItemsOffline(int transactionId) async {
    final db = await localDb.database;
    return await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }
}
