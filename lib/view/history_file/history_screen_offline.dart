import 'package:flutter/material.dart';
import 'package:cashier/database/local_db.dart';

class HistoryScreenOffline extends StatefulWidget {
  const HistoryScreenOffline({super.key});

  @override
  State<HistoryScreenOffline> createState() => _HistoryScreenOfflineState();
}

class _HistoryScreenOfflineState extends State<HistoryScreenOffline> {
  final LocalDatabase localDb = LocalDatabase();

  List<Map<String, dynamic>> transactions = [];
  Map<int, List<Map<String, dynamic>>> transactionItems = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadLocalTransactions();
  }

  Future<void> loadLocalTransactions() async {
    try {
      setState(() => isLoading = true);

      // Kuha tanan transactions nga naa sa local SQLite
      final trx = await localDb.getAllTransactions(); // nag return ug List<Map>

      transactions = trx;

      // Kuha items para sa matag transaction
      for (var t in trx) {
        final items = await localDb.getTransactionItems(t['id']);
        transactionItems[t['id']] = items.map((i) => {
              'product_name': i['product_name'] ?? 'Unknown Product',
              'qty': i['qty'] ?? 0,
              'price': i['price'] ?? 0.0,
            }).toList();
      }
    } catch (e) {
      print("Error loading local transactions: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final t = transactions[index];
                final items = transactionItems[t['id']] ?? [];
                final isOffline = t['is_synced'] == 0;

                return Card(
                  color: isOffline ? Colors.grey[100] : Colors.white,
                  margin: const EdgeInsets.all(8),
                  child: ExpansionTile(
                    leading: isOffline
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Offline",
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          )
                        : null,
                    title: Text("Transaction ${t['id']} - ₱${t['total']}"),
                    subtitle: Text(t['created_at'] ?? ""),
                    children: items.map<Widget>((i) {
                      return ListTile(
                        title: Text("${i['product_name']} x${i['qty']}"),
                        trailing: Text("₱${i['price']}"),
                      );
                    }).toList(),
                  ),
                );
              },
            
    );
  }
}
