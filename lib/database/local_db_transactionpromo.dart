import 'package:cashier/database/local_db.dart';

class LocalDbTransactionpromo {
  final db = LocalDatabase();

Future<int> insertTransactionPromo({
  required int transactionId,
  required int productId,
  required String productName,
  required int promoCount,
  required double retailPrice,
  int isSynced = 0,
}) async {
  final database = await db.database;

  final total = retailPrice * promoCount;

  // ✅ DEBUG PRINT (BEFORE INSERT)
  print('🟡 INSERT PROMO START');
  print('transactionId: $transactionId');
  print('productId: $productId');
  print('productName: $productName');
  print('promoCount: $promoCount');
  print('retailPrice: $retailPrice');
  print('total: $total');
  print('isSynced: $isSynced');

  final id = await database.insert(
    'transaction_promos',
    {
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'promo_count': promoCount,
      'retail_price': retailPrice,
      'total': total,
      'is_synced': isSynced,
    },
  );

  return id;
}

}
