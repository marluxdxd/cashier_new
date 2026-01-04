import 'dart:io';
import 'package:cashier/class/product_offline.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';
import 'package:cashier/services/product_service.dart';
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

  // Fetch all transactions
  /////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////

// Fetch all transactions: merge local unsynced + online
Future<List<Map<String, dynamic>>> fetchAllTransactions({
  DateTime? startDate,
  DateTime? endDate,
}) async {
  // 1️⃣ Get local transactions (both synced and unsynced)
  final localTransactions = await localDb.getAllTransactions();

  // Filter LOCAL by date
  final filteredLocal = localTransactions.where((t) {
    if (t['created_at'] == null) return false;

    final date = DateTime.parse(t['created_at']);

    if (startDate != null && date.isBefore(startDate)) return false;
    if (endDate != null &&
        date.isAfter(endDate.add(const Duration(days: 1)))) {
      return false;
    }

    return true;
  }).toList();

  // 2️⃣ Get online transactions
  List<Map<String, dynamic>> onlineTransactions = [];
  try {
    var query = supabase.from('transactions').select();

    if (startDate != null) {
      query = query.gte(
        'created_at',
        startDate.toIso8601String(),
      );
    }

    if (endDate != null) {
      query = query.lte(
        'created_at',
        endDate.add(const Duration(days: 1)).toIso8601String(),
      );
    }

    final data = await query.order(
      'created_at',
      ascending: false,
    );

    onlineTransactions =
        List<Map<String, dynamic>>.from(data as List<dynamic>);
  } catch (e) {
    print("Failed to fetch online transactions: $e");
  }

  // 3️⃣ Merge local unsynced with online (no duplicates)
  final merged = [
    ...filteredLocal,
    ...onlineTransactions.where(
      (o) => !filteredLocal.any((l) => l['id'] == o['id']),
    ),
  ];

  // 4️⃣ Sort by date DESC
  merged.sort((a, b) =>
      (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

  return merged;
}


  // Fetch items for a specific transaction, local+online
  Future<List<Map<String, dynamic>>> fetchAllTransactionItems(int transactionId, DateTime end) async {
    final localItems = await localDb.getTransactionItemsByTransactionId(transactionId);

    List<Map<String, dynamic>> onlineItems = [];
    try {
      final data = await supabase
          .from('transaction_items')
          .select()
          .eq('transaction_id', transactionId);
      onlineItems = List<Map<String, dynamic>>.from(data as List<dynamic>);
    } catch (e) {
      print("Failed to fetch online transaction items: $e");
    }

    // Merge local items not yet in online
    final merged = [
      ...localItems,
      ...onlineItems.where(
        (o) => !localItems.any((l) => l['id'] == o['id']),
      ),
    ];

    return merged;
  }
  /////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////

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
        'cost_price': item.costPrice,
        'retail_price': item.retailPrice,
        'is_promo': item.isPromo ? 1 : 0,
        'other_qty': item.otherQty,
        'is_synced': 0,
        'product_client_uuid': item.productClientUuid, // ✅ ADD THIS
        
        
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
  final db = await localDb.database;
  final online = await isOnline2();
  if (!online) return;

  final transactions = await db.query(
    'transactions',
    where: 'is_synced = 0',
  );

  for (final trx in transactions) {
    try {
      // 1️⃣ INSERT TRANSACTION TO SUPABASE
      final trxRes = await supabase
          .from('transactions')
          .insert({
            'total': trx['total'],
            'cash': trx['cash'],
            'change': trx['change'],
            'created_at': trx['created_at'],
            'client_uuid': trx['client_uuid'],
          })
          .select()
          .single();

      final supaTransactionId = trxRes['id'] as int;

      // 2️⃣ SAVE SUPABASE ID LOCALLY
      await db.update(
        'transactions',
        {'supabase_id': supaTransactionId},
        where: 'id = ?',
        whereArgs: [trx['id']],
      );

      // 3️⃣ GET LOCAL ITEMS USING LOCAL TRANSACTION ID
      final items = await db.query(
        'transaction_items',
        where: 'transaction_id = ? AND is_synced = 0',
        whereArgs: [trx['id']],
      );

      // 4️⃣ INSERT ITEMS USING SUPABASE TRANSACTION ID
      for (final item in items) {
        await supabase.from('transaction_items').upsert({
          'transaction_id': supaTransactionId, // ✅ FIXED
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'qty': item['qty'],
          'cost_price': item['cost_price'],
          'retail_price': item['retail_price'],
          'is_promo': item['is_promo'] == 1,
          'other_qty': item['other_qty'],
          'product_client_uuid': item['product_client_uuid'] ??
              generateUniqueId(prefix: 'P'),
        }, onConflict: 'product_client_uuid, transaction_id, product_id'); // pass as string, not list


        await db.update(
          'transaction_items',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }

      // 5️⃣ MARK TRANSACTION SYNCED
      await db.update(
        'transactions',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [trx['id']],
      );
      
      
      

      print("✅ Transaction ${trx['id']} synced → Supabase ID $supaTransactionId");
    } catch (e) {
      print("❌ Failed to sync transaction123 ${trx['id']}: $e");
    }
  }
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
  required String clientUuid,
}) async {
  final response = await supabase
      .from('transactions')
      .insert({
        'total': total,
        'cash': cash,
        'change': change,
        'client_uuid': clientUuid, // ✅ IMPORTANT
        'created_at': getPhilippineTimestamp(),
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
      print(
    "🌐 ONLINE INSERT ITEM => ${product.name} uuid=${product.productClientUuid}",
  );
    await supabase.from('transaction_items').insert({
      'transaction_id': transactionId,
      'product_id': product.id,
      'product_name': product.name,
      'qty': qty,
      'cost_price': product.costPrice,
      'retail_price': product.retailPrice,
      'is_promo': isPromo,
      'other_qty': otherQty,
      'product_client_uuid': product.productClientUuid,
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

   Future<List<Map<String, dynamic>>> fetchAllTransactionItems1() async {
    // Join transaction_items with transactions to get created_at
    final res = await supabase
        .from('transaction_items')
        .select('*, transaction:transactions(*)'); // fetch transaction data as nested object

    if (res == null) return [];

    // Convert to List<Map<String, dynamic>>
    final items = List<Map<String, dynamic>>.from(res as List);
    return items;
  }

  /// Fetch all transactions (optional)
  Future<List<Map<String, dynamic>>> fetchAllTransactions1() async {
    final res = await supabase.from('transactions').select('*');
    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res as List);
  }
}
