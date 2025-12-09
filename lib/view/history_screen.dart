import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cashier/database/local_db.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final LocalDatabase localDb = LocalDatabase();
  List<Map<String, dynamic>> transactions = [];
  DateTimeRange? selectedDateRange;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadTransactions() async {
    // Load local transactions first
    transactions = await localDb.getTransactionsWithItems();

    // Fetch online transactions if online
    if (await isOnline()) {
      try {
        final onlineData = await Supabase.instance.client
            .from('transactions')
            .select(
              '''
              id, total, cash, change, created_at, 
              transaction_items(id, product_id, product_name, qty, price, is_promo, other_qty)
              '''
            )
            .order('created_at', ascending: false);

        // onlineData is List<dynamic>
        for (var t in onlineData) {
          final transactionId = t['id'];
          final exists = transactions.any((local) => local['transaction_id'] == transactionId);

          if (!exists) {
            await localDb.insertTransaction(
              id: transactionId,
              total: t['total'],
              cash: t['cash'],
              change: t['change'],
              createdAt: t['created_at'],
            );

            final items = t['transaction_items'] as List<dynamic>? ?? [];
            for (var item in items) {
              await localDb.insertTransactionItem(
                id: item['id'],
                transactionId: transactionId,
                productId: item['product_id'],
                productName: item['product_name'],
                qty: item['qty'],
                price: item['price'],
                isPromo: item['is_promo'] == true || item['is_promo'] == 1,
                otherQty: item['other_qty'] ?? 0,
              );
            }
          }
        }

        // Refresh all transactions after merge
        transactions = await localDb.getTransactionsWithItems();
            } catch (e) {
        print("Failed to fetch online transactions: $e");
      }
    }

    setState(() {});
  }

  Future<void> chooseDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: selectedDateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 7)), 
        end: now,
      ),
    );

    if (picked != null) {
      selectedDateRange = picked;
      filterByDate();
    }
  }

  void filterByDate() {
    if (selectedDateRange == null) return;

    final start = selectedDateRange!.start;
    final end = selectedDateRange!.end.add(const Duration(days: 1));

    setState(() {
      transactions = transactions
          .where((t) {
            final createdAt = DateTime.parse(t['created_at']);
            return createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
                   createdAt.isBefore(end);
          })
          .toList();
    });
  }

  String formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transaction History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: chooseDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadTransactions,
          ),
        ],
      ),
      body: transactions.isEmpty
          ? const Center(child: Text("No transactions found"))
          : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final t = transactions[index];
                // Get items for this transaction
                final items = (t['items'] ?? []) as List<dynamic>;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ExpansionTile(
                    title: Text(
                        "Transaction #${t['transaction_id']} | ₱${t['total']}"),
                    subtitle: Text(
                        "Cash: ₱${t['cash']} | Change: ₱${t['change']} | ${formatDate(t['created_at'])}"),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            for (var item in items)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("${item['product_name']} x${item['qty']}"),
                                  Text("₱${item['price']}"),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
