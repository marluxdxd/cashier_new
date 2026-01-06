import 'package:cashier/database/local_db_transactionpromo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionPromoService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> insertTransactionPromo({
    required int transactionId,
    required int productId,
    required String productName,
    required int promoCount,
    required double retailPrice,
  }) async {
    final total = retailPrice * promoCount;

    await supabase.from('transaction_promos').insert({
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'promo_count': promoCount,
      'retail_price': retailPrice,
      'total': total,
    });

    print('✅ Promo inserted online | productId: $productId count: $promoCount');
  }

  // ----------------- SYNC OFFLINE PROMOS -----------------
  Future<void> syncOfflinePromos() async {
    final localDbPromo = LocalDbTransactionpromo();
    final database = await localDbPromo.db.database;
    final promos = await database.query(
      'transaction_promos',
      where: 'is_synced = 0',
    );

    for (final promo in promos) {
      try {
        await supabase.from('transaction_promos').insert({
          'transaction_id': promo['transaction_id'],
          'product_id': promo['product_id'],
          'product_name': promo['product_name'],
          'promo_count': promo['promo_count'],
          'retail_price': promo['retail_price'],
          'total': promo['total'],
        });

        await database.update(
          'transaction_promos',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [promo['id']],
        );

        print('✅ Offline promo synced | localId: ${promo['id']}');
      } catch (e) {
        print('❌ Failed to sync promo | localId: ${promo['id']} error: $e');
      }
    }
  }
}
