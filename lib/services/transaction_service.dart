import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

//-----------MANUAL--------------------------
// class TransactionService {
//   /// Calculate change given total and cash
//   double calculateChange(double total, double cash) {
//     return cash - total;
//   }

//   /// Get current timestamp formatted as MM-dd-yyyy HH:mm:ss
//   String getCurrentTimestamp() {
//     DateTime now = DateTime.now();
//     return DateFormat('MM-dd-yyyy HH:mm:ss').format(now);
//   }

//   /// Validate if cash is enough
//   bool isCashSufficient(double total, double cash) {
//     return cash >= total;
//   }
// }








//-------------SUPABASE-----------------------

class TransactionService {
  final supabase = Supabase.instance.client;

  // ------------------------------
  // VALIDATION + CALCULATIONS
  // ------------------------------

  bool isCashSufficient(double total, double cash) {
    return cash >= total;
  }

  double calculateChange(double total, double cash) {
    return cash - total;
  }

// int minusQty(QT){
//   return 
// }


  // DATE & TIME
  String getCurrentTimestamp() {
    return DateTime.now().toIso8601String();
  }

  // ------------------------------
  // SAVE TRANSACTION (HEADER)
  // ------------------------------

  Future<int> saveTransaction({
    required double total,
    required double cash,
    required double change,
  }) async {
    final response = await supabase
        .from('transactions')
        .insert({'total': total, 'cash': cash, 'change': change})
        .select('id')
        .single();

    return response['id'];
  }

  // ------------------------------
  // SAVE TRANSACTION ITEM (DETAILS)
  // ------------------------------

  Future<void> saveTransactionItem({
    required int transactionId,
    required dynamic product,
    required int qty,
    required bool isPromo,
    required int otherQty,

  }) async {
    await supabase.from('transaction_items').insert({
       'transaction_id': transactionId, // link sa main transaction
    'product_id': product.id,        // unsang product ni
    'product_name': product.name,    // record sa name sa time sa sale
    'qty': qty,
    'price': product.price, 
    'is_promo': isPromo,    // price sa time sa sale
    'other_qty': otherQty,  
    });
  }
//---------------- I-update ang Stock sa Product
Future<void> updateStock({
  required int productId,
  required int newStock,
}) async {
  await supabase.from('products').update({'stock': newStock}).eq('id', productId);
}



}
