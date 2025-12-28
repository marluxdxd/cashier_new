import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';
import 'package:uuid/uuid.dart';

class StockHistorySyncService {
  final localDb = LocalDatabase();
  final supabase = SupabaseConfig.supabase;
  final _uuid = Uuid();

  /// 🔄 Sync offline product_stock_history to Supabase
  Future<void> syncStockHistory() async {
    final db = await localDb.database;

    // 1️⃣ Get all UNSYNCED stock history
    final unsyncedHistory = await db.query(
      'product_stock_history',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    if (unsyncedHistory.isEmpty) {
      print('ℹ️ No stock history to sync');
      return;
    }

    for (final entry in unsyncedHistory) {
      print("🔍 Processing stock history id=${entry['id']}, product_id=${entry['product_id']}, qty_changed=${entry['qty_changed']}, client_uuid=${entry['product_client_uuid']}");

      try {
        // 2️⃣ Ensure product_client_uuid exists
        String clientUuid = entry['product_client_uuid']?.toString() ?? '';
        if (clientUuid.isEmpty) {
          clientUuid = _uuid.v4();
          await db.update(
            'product_stock_history',
            {'product_client_uuid': clientUuid},
            where: 'id = ?',
            whereArgs: [entry['id']],
          );
        }

        // 3️⃣ Get local product using client_uuid
        final productList = await db.query(
          'products',
          where: 'client_uuid = ?',
          whereArgs: [clientUuid],
        );

        if (productList.isEmpty) {
          print('⚠️ Product not found locally for stock history id ${entry['id']}. Skipping.');
          continue;
        }

        final product = productList.first;

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
          final inserted = await supabase
              .from('products')
              .insert({
                'name': product['name'] ?? 'UNKNOWN',
                'price': product['price'] ?? 0.0,
                'stock': product['stock'] ?? 0,
                'is_promo': product['is_promo'] == 1,
                'other_qty': product['other_qty'] ?? 0,
                'client_uuid': clientUuid,
              })
              .select('id')
              .single();

          supaProductId = inserted['id'] as int;
          print('➕ Inserted missing product "${product['name']}" to Supabase');
        }

        // 5️⃣ Insert stock history into Supabase
   await supabase.from('product_stock_history').insert({
  'product_id': supaProductId,
  'product_name': entry['product_name'] ?? product['name'] ?? 'UNKNOWN',
  'old_stock': entry['old_stock'] ?? 0,
  'new_stock': entry['new_stock'] ?? 0,
  'qty_changed': entry['qty_changed'] ?? 0,
  'change_type': entry['change_type']?.toString() ?? 'adjust',
  'trans_date': entry['trans_date']?.toString() ?? DateTime.now().toIso8601String(),
  'created_at': entry['created_at']?.toString() ?? DateTime.now().toIso8601String(),
  'product_client_uuid': clientUuid,
});
print("✅ Synced to Supabase: stock_history_id=${entry['id']}, product_id=$supaProductId, qty_changed=${entry['qty_changed']}");

        


        // 6️⃣ Mark as synced locally
        await db.update(
          'product_stock_history',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [entry['id']],
        );

        print('✅ Synced stock history id ${entry['id']} | product=${supaProductId}');
      } catch (e) {
        print('❌ Failed to sync stock history id ${entry['id']}: $e');
      }
    }

    print('🎉 All offline stock history synced!');
  }
}
