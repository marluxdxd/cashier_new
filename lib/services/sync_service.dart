import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:uuid/uuid.dart';

final uuid = Uuid();

class SyncService {
  final LocalDatabase localDb = LocalDatabase();
  final supabase = SupabaseConfig.supabase;

  Future<void> syncOfflineProducts() async {
    // copy code from ProductService.syncOfflineProducts()
  }

  Future<void> syncOfflineTransactions() async {
    // copy code from TransactionService.syncOfflineTransactions()
  }





  Future<void> sync() async {
    bool online = await InternetConnectionChecker().hasConnection;
    if (!online) return;

    print("SYNC: Checking unsynced transactions...");

    // 1️⃣ Get all unsynced transactions
    final unsyncedTrx = await localDb.getUnsyncedTransactions();

    for (var trx in unsyncedTrx) {
      print("Uploading Transaction ID ${trx['id']}");

      try {
        // 2️⃣ Insert to Supabase, let Supabase generate its integer ID
        final uploaded = await supabase
            .from('transactions')
            .insert({
              'total': trx['total'],
              'cash': trx['cash'],
              'change': trx['change'],
              'created_at': trx['created_at'],
            })
            .select()
            .single();

        int supabaseTrxId = uploaded['id'];

        // 3️⃣ Get all items for this transaction
        final items = await localDb.getItemsForTransaction(trx['id']);

        for (var item in items) {
          await supabase.from('transaction_items').insert({
            'transaction_id': supabaseTrxId, // ← use Supabase ID
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

        // 4️⃣ Mark transaction synced locally
        await localDb.markTransactionSynced(trx['id']);

        print("SYNCED Transaction #${trx['id']} → Supabase ID: $supabaseTrxId");
      } catch (e) {
        print("Failed to sync transaction ${trx['id']}: $e");
      }
    }

    print("All offline transactions synced!");
  }

  // Optional: generate UUID for local offline IDs
  String generateOfflineId() => uuid.v4();
}
