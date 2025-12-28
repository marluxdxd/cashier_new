import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final uuid = Uuid();

class SyncService {
  final LocalDatabase localDb = LocalDatabase();
  final supabase = SupabaseConfig.supabase;
  final supabase1 = Supabase.instance.client;

  Future<void> syncOfflineProducts() async {
    // copy code from ProductService.syncOfflineProducts()
  }

  Future<void> syncOfflineTransactions() async {
    // copy code from TransactionService.syncOfflineTransactions()
  }

  Future<void> syncPendingStockUpdates() async {
    final updates = await localDb.getUnsyncedStockUpdates();

    for (var u in updates) {
      try {
        await Supabase.instance.client
            .rpc('decrement_stock', params: {
              'product_id': u['product_id'],
              'qty': u['qty'],
            });
        await localDb.markStockUpdateSynced(u['id']);
        print("Synced stock update for product ${u['product_id']}");
      } catch (e) {
        print("Failed to sync stock update: $e");
      }
    }
  }
  // Optional: generate UUID for local offline IDs
  String generateOfflineId() => uuid.v4();

  
}
