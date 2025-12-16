import 'package:cashier/services/transaction_service.dart';
import 'package:flutter/material.dart';


class HistoryScreenOnline extends StatefulWidget {
  const HistoryScreenOnline({super.key});

  @override
  State<HistoryScreenOnline> createState() => _HistoryScreenOnlineState();
}

class _HistoryScreenOnlineState extends State<HistoryScreenOnline> {
  final TransactionService transactionService = TransactionService();

  List<Map<String, dynamic>> transactions = [];
  Map<int, List<Map<String, dynamic>>> transactionItems = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    try {
      // Fetch all transactions
      final trx = await transactionService.fetchTransactions();
      setState(() => transactions = trx);

      // Fetch items for each transaction
      for (var t in trx) {
        final items = await transactionService.fetchTransactionItems(t['id']);
        setState(() {
          transactionItems[t['id']] = items;
        });
      }
    } catch (e) {
      print("Error loading transactions: $e");
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

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ExpansionTile(
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
