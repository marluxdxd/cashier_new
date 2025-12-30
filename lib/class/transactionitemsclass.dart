// import 'package:cashier/database/local_db.dart';

// Future<void> insertTransactionItem({
//   required int id,
//   required int transactionId,
//   required int productId,
//   required String productName,
//   required int qty,
//   required double price,
//   required bool isPromo,
//   required int otherQty,
//   required String productClientUuid,
// }) async {
//   final db = await localDb.database;

//   await db.insert(
//     'transaction_items',
//     {
//       'id': id,
//       'transaction_id': transactionId,
//       'product_id': productId,
//       'product_name': productName,
//       'qty': qty,
//       'price': price,
//       'is_promo': isPromo ? 1 : 0,
//       'other_qty': otherQty,
//       'product_client_uuid': productClientUuid,
//     },
//   );
// }
