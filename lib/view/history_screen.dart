import 'package:flutter/material.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/services/product_service.dart'; // for online check

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final LocalDatabase localDb = LocalDatabase();
  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  // ------------------ SYNC ONLINE TRANSACTIONS ------------------
 Future<void> syncOnlineTransactions() async {
  final productService = ProductService();
  final online = await productService.isOnline();
  if (!online) return;

  try {
    final supaTransactions =
        await productService.supabase.from('transactions').select();

    for (var t in supaTransactions) {
      // Insert locally only if it doesn't exist
      final existsLocally = await localDb.getAllTransactions().then(
          (list) => list.any((trx) => trx['id'] == t['id']));

      if (!existsLocally) {
        await localDb.insertTransaction(
          id: t['id'],
          total: (t['total'] as num).toDouble(),
          cash: (t['cash'] as num).toDouble(),
          change: (t['change'] as num).toDouble(),
          createdAt: t['created_at'] as String?,
        );

        // Fetch items
        final items = await productService.supabase
            .from('transaction_items')
            .select()
            .eq('transaction_id', t['id']);

        for (var item in items) {
          await localDb.insertTransactionItem(
            id: item['id'],
            transactionId: t['id'],
            productId: item['product_id'],
            productName: item['product_name'],
            qty: item['qty'],
            price: (item['price'] as num).toDouble(),
            isPromo: item['is_promo'] ?? false,
            otherQty: item['other_qty'] ?? 0,
          );
        }
      }
    }
  } catch (e) {
    print("Error syncing online transactions: $e");
  }
}


  // ------------------ LOAD AND SORT TRANSACTIONS ------------------
  Future<void> loadTransactions() async {
    await syncOnlineTransactions();

    final data = await localDb.getAllTransactions();

    // Make a mutable copy
    final transactionsList = List<Map<String, dynamic>>.from(data);

    // Sort by created_at descending
    transactionsList.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA); // newest first
    });

    setState(() {
      transactions = transactionsList;
    });
  }

  Future<List<Map<String, dynamic>>> getTransactionItems(int transactionId) async {
    return await localDb.getTransactionItems(transactionId);
  }

  // ------------------ BUILD UI ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
      ),
      body: transactions.isEmpty
          ? const Center(child: Text('No transactions yet.'))
          : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final trx = transactions[index];
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: getTransactionItems(trx['id']),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Text(
                          "₱${trx['total'].toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Cash: ₱${trx['cash'].toStringAsFixed(2)} | Change: ₱${trx['change'].toStringAsFixed(2)}\nDate: ${trx['created_at'] ?? ''}",
                        ),
                        children: items.map((item) {
                          final isPromo = (item['is_promo'] == 1 || item['is_promo'] == true);
                          final totalPrice = isPromo
                              ? item['price'] as double
                              : (item['qty'] * (item['price'] as double));

                          return ListTile(
                            title: Text(item['product_name']),
                            subtitle: Text(
                                "Qty: ${item['qty']} | Price: ₱${(item['price'] as double).toStringAsFixed(2)}"),
                            trailing: Text(
                              "₱${totalPrice.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
