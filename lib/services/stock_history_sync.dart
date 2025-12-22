import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';


class StockHistorySyncService {
 final localDb = LocalDatabase();
  final supabase = SupabaseConfig.supabase;



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

    // 2️⃣ Sync ONE BY ONE (SAFE MODE)
    for (final entry in unsyncedHistory) {
      try {
        // 🚨 SAFETY CHECK (avoid null crash)
        if (entry['type'] == null) {
          print(
            '⚠️ Skipped stock history ${entry['id']} — type is NULL',
          );
          continue;
        }

        // 3️⃣ Insert into Supabase
        await supabase.from('product_stock_history').insert({
          'product_id': entry['product_id'],
          'old_stock': entry['old_stock'],
          'new_stock': entry['new_stock'],
          'qty_changed': entry['qty_changed'],
          'change_type': entry['type'], // ✅ FIXED COLUMN NAME
          'created_at': entry['created_at'],
        });

        // 4️⃣ Mark as synced locally
        await db.update(
          'product_stock_history',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [entry['id']],
        );

        print(
          '✅ Stock history synced | id=${entry['id']} product=${entry['product_id']}',
        );
      } catch (e) {
        print(
          '❌ Failed to sync stock history id ${entry['id']}: $e',
        );
      }
    }

    print('🎉 All offline stock history sync finished');
  }
}
