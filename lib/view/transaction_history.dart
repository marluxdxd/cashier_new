import 'package:flutter/material.dart';
import 'package:cashier/database/local_db.dart';

import 'package:cashier/database/supabase.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = SupabaseConfig.supabase;

  List<Map<String, dynamic>> localTransactions = [];
  List<Map<String, dynamic>> serverTransactions = [];
  Map<int, List<Map<String, dynamic>>> serverTransactionItems = {}; // key: transaction_id

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchLocalTransactions();
    fetchServerTransactions();
  }

  // ------------------- LOCAL -------------------
  Future<void> fetchLocalTransactions() async {
    final db = await LocalDatabase().database;
    final txs = await db.query('transactions', orderBy: 'created_at DESC');
    if (!mounted) return;
    setState(() => localTransactions = txs);
  }

  // ------------------- SERVER -------------------
  Future<void> fetchServerTransactions() async {
    try {
      final txList = await supabase
          .from('transactions')
          .select('*')
          .order('created_at', ascending: false);

      final txListData = List<Map<String, dynamic>>.from(txList as List);

      // Fetch transaction_items for each transaction
      Map<int, List<Map<String, dynamic>>> itemsMap = {};
      for (var tx in txListData) {
        final txId = tx['id'] as int;
        final itemResponse = await supabase
            .from('transaction_items')
            .select('*')
            .eq('transaction_id', txId);
        itemsMap[txId] = List<Map<String, dynamic>>.from(itemResponse as List);
      }

      if (!mounted) return;
      setState(() {
        serverTransactions = txListData;
        serverTransactionItems = itemsMap;
      });
    } catch (e) {
      print('❌ Supabase fetch error: $e');
    }
  }

  double computeTotalFromItems(List<Map<String, dynamic>> items) {
    double total = 0;
    for (var item in items) {
      final qty = item['qty'] as int;
      final price = (item['price'] as num).toDouble();
      total += qty * price;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Phone'),
            Tab(text: 'Server'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ---------------- PHONE TAB ----------------
          RefreshIndicator(
            onRefresh: fetchLocalTransactions,
            child: ListView.builder(
              itemCount: localTransactions.length,
              itemBuilder: (_, index) {
                final tx = localTransactions[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text("Total: ₱${(tx['total'] as num).toStringAsFixed(2)}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Cash: ₱${(tx['cash'] as num).toStringAsFixed(2)} | Change: ₱${(tx['change'] as num).toStringAsFixed(2)}"),
                        Text("Created at: ${tx['created_at']}"),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ---------------- SERVER TAB ----------------
          RefreshIndicator(
            onRefresh: fetchServerTransactions,
            child: ListView.builder(
              itemCount: serverTransactions.length,
              itemBuilder: (_, index) {
                final tx = serverTransactions[index];
                final txId = tx['id'] as int;
                final items = serverTransactionItems[txId] ?? [];
                final computedTotal = computeTotalFromItems(items);

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ExpansionTile(
                    title: Text("Transaction #$txId - Total: ₱${computedTotal.toStringAsFixed(2)}"),
                    subtitle: Text("Cash: ₱${(tx['cash'] as num).toStringAsFixed(2)} | Change: ₱${(tx['change'] as num).toStringAsFixed(2)}"),
                    children: items.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(8), child: Text("No items"))]
                        : items.map((item) {
                            return ListTile(
                              title: Text("${item['product_name']}"),
                              subtitle: Text("Qty: ${item['qty']} x ₱${(item['price'] as num).toStringAsFixed(2)}"),
                              trailing: Text("₱${((item['qty'] as int) * (item['price'] as num)).toStringAsFixed(2)}"),
                            );
                          }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
