import 'package:cashier/database/supabase.dart';
import 'package:flutter/material.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/services/sync_service.dart';
import 'package:cashier/services/transaction_service.dart';
import 'package:cashier/services/product_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final supabase = SupabaseConfig.supabase;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _loading = true;
    });

    final db = await LocalDatabase().database;
    final history = await db.rawQuery('''
      SELECT 
        h.*,
        t.total
      FROM product_stock_history h
      LEFT JOIN transactions t
        ON h.transaction_id = t.id
      ORDER BY h.trans_date DESC
    ''');

    setState(() {
      _history = history;
      _loading = false;
    });
  }

  Future<void> _syncHistory() async {
    setState(() => _loading = true);

    await syncOfflineStockHistory();
    await _fetchHistory();

    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stock history synced!')),
    );
  }

  Color _getSyncColor(int isSynced) {
    return isSynced == 1 ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncHistory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No stock history found'))
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final entry = _history[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _getSyncColor(entry['is_synced'] ?? 0),
                          child: const Icon(Icons.inventory),
                        ),
                        title: Text(
                          '${entry['product_name']} | Qty: ${entry['qty_changed']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Old Stock: ${entry['old_stock']}'),
                            Text('New Stock: ${entry['new_stock']}'),
                            Text('Type: ${entry['change_type'] ?? 'adjust'}'),
                            Text(
                              'Total Sale: ₱${entry['total'] ?? 0}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('Date: ${entry['trans_date']}'),
                          ],
                        ),
                        trailing: entry['is_synced'] == 1
                            ? const Icon(Icons.check, color: Colors.green)
                            : const Icon(Icons.cloud_upload,
                                color: Colors.red),
                      ),
                    );
                  },
                ),
    );
  }
  
  Future<void> syncOfflineStockHistory() async {
  print("📦 syncOfflineStockHistory START");
  final db = await LocalDatabase().database;

  // 1️⃣ Kuhaon tanan unsynced stock history
  final unsyncedHistory = await db.query(
    'product_stock_history',
    where: 'is_synced = ?',
    whereArgs: [0],
  );
  print("➡️ Unsynced history count: ${unsyncedHistory.length}");

  if (unsyncedHistory.isEmpty) {
    print("✅ No stock history to sync");
    return;
  }

  for (var entry in unsyncedHistory) {
    try {
      // 2️⃣ Siguraduhon na naa product_client_uuid
      String clientUuid = entry['product_client_uuid']?.toString() ?? '';
      if (clientUuid.isEmpty) {
        print("❌ WALAY product_client_uuid ang stock history id ${entry['id']}. Skipping.");
        continue;
      }

      // 3️⃣ Kuhaon ang product locally gamit ang client_uuid
      final productList = await db.query(
        'products',
        where: 'client_uuid = ?',
        whereArgs: [clientUuid],
      );

      if (productList.isEmpty) {
        print("⚠️ Product not found locally for stock history id ${entry['id']}. Skipping.");
        continue;
      }

      final product = productList.first;

      // 4️⃣ Siguraduhon product exists sa Supabase
      final supaProduct = await supabase
          .from('products')
          .select('id')
          .eq('client_uuid', clientUuid)
          .maybeSingle();

      int supaProductId;

      if (supaProduct != null) {
        supaProductId = supaProduct['id'] as int;
      } else {
        // Insert product kung wala pa sa Supabase
        final inserted = await supabase
            .from('products')
            .insert({
              'name': product['name'] ?? 'UNKNOWN',
              'cost_price': product['cost_price'] ?? 0.0,
              'retail_price': product['retail_price'] ?? 0.0,
              'stock': product['stock'] ?? 0,
              'is_promo': product['is_promo'] == 1,
              'other_qty': product['other_qty'] ?? 0,
              'client_uuid': clientUuid,
            })
            .select('id')
            .maybeSingle();

        if (inserted == null || inserted['id'] == null) {
          print("❌ Failed to insert product '${product['name']}'. Skipping stock history.");
          continue;
        }

        supaProductId = inserted['id'] as int;
        print("➕ Inserted missing product '${product['name']}' to Supabase");
      }

      print("🔍 SYNCING STOCK HISTORY ENTRY ID: ${entry['id']}");
      print("➡️ supaProductId: $supaProductId");
      print("➡️ clientUuid: $clientUuid");

      // 5️⃣ Insert stock history sa Supabase
      try {
        await supabase.from('product_stock_history').insert({
          'product_id': supaProductId,
          'product_name': entry['product_name'] ?? 'UNKNOWN',
          'old_stock': entry['old_stock'],
          'new_stock': entry['new_stock'],
          'qty_changed': entry['qty_changed'],
          'change_type': entry['change_type']?.toString() ?? 'adjust',
          'trans_date': entry['trans_date']?.toString() ?? DateTime.now().toIso8601String(),
          'created_at': entry['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          'product_client_uuid': clientUuid,
        });
      } catch (e) {
        print("❌ Failed to insert stock history id ${entry['id']} to Supabase: $e");
        continue;
      }

      // 6️⃣ Mark as synced locally
      await db.update(
        'product_stock_history',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [entry['id']],
      );

      print("✅ Synced stock history id ${entry['id']}");
    } catch (e) {
      print("❌ Failed to sync stock history id ${entry['id']}: $e");
    }
  }

  print("🎉 All offline stock history synced!");
}
}
