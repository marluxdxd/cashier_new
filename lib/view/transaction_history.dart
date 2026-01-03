import 'package:flutter/material.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/supabase.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>

    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = SupabaseConfig.supabase;

  List<Map<String, dynamic>> localTransactions = [];
  List<Map<String, dynamic>> serverTransactions = [];
  Map<int, List<Map<String, dynamic>>> serverTransactionItems = {}; // key: transaction_id
StreamSubscription<ConnectivityResult>? _connectivitySub;
StreamSubscription<InternetConnectionStatus>? _internetSub;
@override
void initState() {
  super.initState();
  _tabController = TabController(length: 2, vsync: this);

  fetchLocalTransactions();
  fetchServerTransactions();

  // 🔥 AUTO REFRESH WHEN INTERNET COMES BACK
  _internetSub =
      InternetConnectionChecker().onStatusChange.listen((status) async {
    if (status == InternetConnectionStatus.connected) {
      await fetchLocalTransactions();   // removes synced items
      await fetchServerTransactions();  // loads server data
    }
  });
}



  // ------------------- LOCAL -------------------
 Future<void> fetchLocalTransactions() async {
  final db = await LocalDatabase().database;

  // 🔥 SHOW ONLY OFFLINE TRANSACTIONS
  final txs = await db.query(
    'transactions',
    where: 'is_synced = ?',
    whereArgs: [0], // offline only
    orderBy: 'created_at DESC',
  );

  if (!mounted) return;
  setState(() => localTransactions = txs);
}


  Future<List<Map<String, dynamic>>> fetchLocalTransactionItems(int txId) async {
    final db = await LocalDatabase().database;
    final items = await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [txId],
    );
    return List<Map<String, dynamic>>.from(items);
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
      final retailPrice = (item['retail_price'] as num).toDouble();

      total += qty * price;
      total += qty * retailPrice;
    }
    return total;
  }

  Widget buildTransactionCard(
      {required int txId,
      required double cash,
      required double change,
      required Future<List<Map<String, dynamic>>> itemsFuture}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: itemsFuture,
      builder: (_, snapshot) {
        final items = snapshot.data ?? [];
        final computedTotal = computeTotalFromItems(items);

        return Card(
          margin: const EdgeInsets.all(8),
          child: ExpansionTile(
            title: Text("Transaction #$txId - Total: ₱${computedTotal.toStringAsFixed(2)}"),
            subtitle: Text("Cash: ₱${cash.toStringAsFixed(2)} | Change: ₱${change.toStringAsFixed(2)}"),
            children: items.isEmpty
                ? [const Padding(padding: EdgeInsets.all(8), child: Text("No items"))]
                : items.map((item) {
                    return ListTile(
                      title: Text("${item['product_name']}"),
                      subtitle: Text(
                          "Qty: ${item['qty']} x ₱${(item['retail_price'] as num).toStringAsFixed(2)}"),
                      trailing: Text(
                          "₱${((item['qty'] as int) * (item['retail_price'] as num)).toStringAsFixed(2)}"),
                    );
                  }).toList(),
          ),
        );
      },
    );
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
                final txId = tx['id'] as int;
                return buildTransactionCard(
                  txId: txId,
                  cash: (tx['cash'] as num).toDouble(),
                  change: (tx['change'] as num).toDouble(),
                  itemsFuture: fetchLocalTransactionItems(txId),
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
                return buildTransactionCard(
                  txId: txId,
                  cash: (tx['cash'] as num).toDouble(),
                  change: (tx['change'] as num).toDouble(),
                  itemsFuture: Future.value(items),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
