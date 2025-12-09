// import 'dart:io';
// import 'package:cashier/database/local_db.dart';
// import 'package:cashier/database/supabase.dart';

// class TransactionService {
//   final LocalDatabase localDb = LocalDatabase();
//   final supabase = SupabaseConfig.supabase;

//   // Check online
//   Future<bool> isOnline() async {
//     try {
//       final result = await InternetAddress.lookup('example.com');
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } catch (_) {
//       return false;
//     }
//   }

//   // Get transactions with items
//   Future<List<Map<String, dynamic>>> getTransactionsWithItems() async {
//     final online = await isOnline();
//     if (online) {
//       // Fetch from Supabase
//       final data = await supabase.rpc('get_transactions_with_items').execute();
//       if (data.error == null) {
//         return List<Map<String, dynamic>>.from(data.data);
//       } else {
//         print("Supabase fetch error: ${data.error!.message}");
//         // fallback to local
//         return await localDb.getTransactionsWithItems();
//       }
//     } else {
//       // Offline: local DB
//       return await localDb.getTransactionsWithItems();
//     }
//   }
// }
