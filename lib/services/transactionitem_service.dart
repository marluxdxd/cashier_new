// import 'package:intl/intl.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class TransactionService {
//   final SupabaseClient supabase = Supabase.instance.client;

//   double calculateChange(double total, double cash) => cash - total;

//   bool isCashSufficient(double total, double cash) => cash >= total;

//   String getCurrentTimestamp() =>
//       DateFormat('MM-dd-yyyy HH:mm:ss').format(DateTime.now());

//   Future<int> saveTransactionWithItems({
//     required double total,
//     required double cash,
//     required double change,
//     required List<TransactionRow> rows,
//   }) async {
//     // 1️⃣ Insert transaction
//     final transactionResponse = await supabase
//         .from('transactions')
//         .insert({
//           'total': total,
//           'cash': cash,
//           'change': change,
//         })
//         .select()
//         .single();

//     final transactionId = transactionResponse['id'];

//     // 2️⃣ Insert transaction_items
//     for (var row in rows) {
//       if (row.product != null && row.qty > 0) {
//         final item = TransactionItem(
//           transactionId: transactionId,
//           productId: row.product!.id,
//           productName: row.product!.name,
//           qty: row.qty,
//           price: row.product!.price,
//         );

//         await supabase.from('transaction_items').insert(item.toMap());
//       }
//     }

//     return transactionId;
//   }
// }
