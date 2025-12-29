// import 'package:cashier/database/local_db.dart';
// import 'package:cashier/database/supabase.dart';

// class SyncManager {
//   final _db = LocalDatabase();
//   final _supabase = SupabaseConfig.supabase;

//   bool _isSyncing = false;

//   Future<void> syncAll() async {
//     if (_isSyncing) return;
//     _isSyncing = true;

//     try {
//       await syncProducts();
//       await syncTransactions();
//       await syncTransactionItems();
//       await syncStockHistory();
//       print("🎉 FULL SYNC COMPLETED");
//     } finally {
//       _isSyncing = false;
//     }
//   }

//   // --------------------------------------------------
//   // 1️⃣ PRODUCTS
//   // --------------------------------------------------
//   Future<void> syncProducts() async {
//     final db = await _db.database;
//     final products = await db.query(
//       'products',
//       where: 'is_synced = 0',
//     );

//     for (final p in products) {
//       final clientUuid = p['client_uuid'];
//       if (clientUuid == null) continue;

//       final existing = await _supabase
//           .from('products')
//           .select('id')
//           .eq('client_uuid', clientUuid)
//           .maybeSingle();

//       int supaId;

//       if (existing != null) {
//         supaId = existing['id'];
//         await _supabase.from('products').update({
//           'name': p['name'],
//           'price': p['price'],
//           'stock': p['stock'],
//           'is_promo': p['is_promo'] == 1,
//           'other_qty': p['other_qty'],
//         }).eq('id', supaId);
//       } else {
//         final inserted = await _supabase.from('products').insert({
//           'name': p['name'],
//           'price': p['price'],
//           'stock': p['stock'],
//           'is_promo': p['is_promo'] == 1,
//           'other_qty': p['other_qty'],
//           'client_uuid': clientUuid,
//         }).select('id').single();
//         supaId = inserted['id'];
//       }

//       await db.update(
//         'products',
//         {'supabase_id': supaId, 'is_synced': 1},
//         where: 'id = ?',
//         whereArgs: [p['id']],
//       );
//     }
//   }

//   // --------------------------------------------------
//   // 2️⃣ TRANSACTIONS
//   // --------------------------------------------------
//   Future<void> syncTransactions() async {
//     final db = await _db.database;
//     final txs = await db.query(
//       'transactions',
//       where: 'is_synced = 0',
//     );

//     for (final t in txs) {
//       final inserted = await _supabase.from('transactions').insert({
//         'total': t['total'],
//         'cash': t['cash'],
//         'change': t['change'],
//         'offline_id': t['id'],
//       }).select('id').single();

//       await db.update(
//         'transactions',
//         {
//           'supabase_id': inserted['id'],
//           'is_synced': 1,
//         },
//         where: 'id = ?',
//         whereArgs: [t['id']],
//       );
//     }
//   }

//   // --------------------------------------------------
//   // 3️⃣ TRANSACTION ITEMS
//   // --------------------------------------------------
//   Future<void> syncTransactionItems() async {
//     final db = await _db.database;
//     final items = await db.query(
//       'transaction_items',
//       where: 'is_synced = 0',
//     );

//     for (final item in items) {
//       final product = (await db.query(
//         'products',
//         where: 'id = ?',
//         whereArgs: [item['product_id']],
//       ))
//           .first;

//       final tx = (await db.query(
//         'transactions',
//         where: 'id = ?',
//         whereArgs: [item['transaction_id']],
//       ))
//           .first;

//       if (product['supabase_id'] == null || tx['supabase_id'] == null) {
//         continue;
//       }

//       await _supabase.from('transaction_items').insert({
//         'transaction_id': tx['supabase_id'],
//         'product_id': product['supabase_id'],
//         'qty': item['qty'],
//         'price': item['price'],
//         'product_name': item['product_name'],
//         'product_client_uuid': product['client_uuid'],
//       });

//       await db.update(
//         'transaction_items',
//         {'is_synced': 1},
//         where: 'id = ?',
//         whereArgs: [item['id']],
//       );
//     }
//   }

//   // --------------------------------------------------
//   // 4️⃣ STOCK HISTORY
//   // --------------------------------------------------
//   Future<void> syncStockHistory() async {
//     final db = await _db.database;
//     final history = await db.query(
//       'product_stock_history',
//       where: 'is_synced = 0',
//     );

//     for (final h in history) {
//       final product = (await db.query(
//         'products',
//         where: 'client_uuid = ?',
//         whereArgs: [h['product_client_uuid']],
//       ))
//           .first;

//       if (product['supabase_id'] == null) continue;

//       await _supabase.from('product_stock_history').insert({
//         'product_id': product['supabase_id'],
//         'product_name': h['product_name'],
//         'old_stock': h['old_stock'],
//         'new_stock': h['new_stock'],
//         'qty_changed': h['qty_changed'],
//         'change_type': h['change_type'],
//         'trans_date': h['trans_date'],
//         'created_at': h['created_at'],
//         'product_client_uuid': h['product_client_uuid'],
//       });

//       await db.update(
//         'product_stock_history',
//         {'is_synced': 1},
//         where: 'id = ?',
//         whereArgs: [h['id']],
//       );
//     }
//   }
// }
