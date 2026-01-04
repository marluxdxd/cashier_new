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
  Map<int, List<Map<String, dynamic>>> serverTransactionItems = {};

  StreamSubscription<ConnectivityResult>? _connectivitySub;
  StreamSubscription<InternetConnectionStatus>? _internetSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    fetchLocalTransactions();
    fetchServerTransactions();

    // 🔥 Auto-refresh when internet comes back
    _internetSub =
        InternetConnectionChecker().onStatusChange.listen((status) async {
      if (status == InternetConnectionStatus.connected) {
        await fetchLocalTransactions();
        await fetchServerTransactions();
      }
    });
  }

  // ------------------- LOCAL -------------------
  Future<void> fetchLocalTransactions() async {
    final db = await LocalDatabase().database;

    // Fetch offline transactions with items using JOIN
    final history = await db.rawQuery('''
      SELECT 
        t.id as tx_id,
        t.total,
        t.cash,
        t.change,
        t.created_at,
        ti.id as item_id,
        ti.product_name,
        ti.qty,
        ti.retail_price,
        ti.is_promo
      FROM transactions t
      LEFT JOIN transaction_items ti
        ON t.id = ti.transaction_id
      WHERE t.is_synced = 0
      ORDER BY t.created_at DESC, ti.id ASC
    ''');

    // Group transactions with items
    Map<int, Map<String, dynamic>> grouped = {};
    for (var row in history) {
      final txId = row['tx_id'] as int;

      if (!grouped.containsKey(txId)) {
        grouped[txId] = {
          'tx_id': txId,
          'total': (row['total'] as num).toDouble(),
          'cash': (row['cash'] as num).toDouble(),
          'change': (row['change'] as num).toDouble(),
          'created_at': row['created_at'],
          'items': <Map<String, dynamic>>[],
        };
      }

      if (row['item_id'] != null) {
        grouped[txId]!['items'].add({
          'product_name': row['product_name'],
          'qty': row['qty'],
          'retail_price': (row['retail_price'] as num).toDouble(),
          'is_promo': row['is_promo'],
        });
      }
    }

    if (!mounted) return;
    setState(() {
      localTransactions = grouped.values.toList();
    });
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

  // ------------------- CARD -------------------
  Widget buildTransactionCard({
    required int txId,
    required double total,
    required double cash,
    required double change,
    required List<Map<String, dynamic>> items,
  }) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title:
            Text("Transaction #$txId - Total: ₱${total.toStringAsFixed(2)}"),
        subtitle: Text(
            "Cash: ₱${cash.toStringAsFixed(2)} | Change: ₱${change.toStringAsFixed(2)}"),
        children: items.isEmpty
            ? [const Padding(
                padding: EdgeInsets.all(8),
                child: Text("No items"),
              )]
            : items.map((item) {
                final bool isPromo =
                    item['is_promo'] == true || item['is_promo'] == 1;
                final int qty = item['qty'];
                final double retailPrice =
                    (item['retail_price'] as num).toDouble();
                final double rowTotal = isPromo ? retailPrice : retailPrice * qty;

                return ListTile(
  title: Text(item['product_name']),
  subtitle: isPromo
      ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            "PROMO ${qty}x₱${retailPrice.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
      : Text("Qty: $qty × ₱${retailPrice.toStringAsFixed(2)}"),
  trailing: Text("Total: ₱${rowTotal.toStringAsFixed(2)}"),
);

              }).toList(),
      ),
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
                return buildTransactionCard(
                  txId: tx['tx_id'],
                  total: tx['total'],
                  cash: tx['cash'],
                  change: tx['change'],
                  items: tx['items'],
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
                final items = serverTransactionItems[tx['id']] ?? [];
                return buildTransactionCard(
                  txId: tx['id'],
                  total: (tx['total'] as num).toDouble(),
                  cash: (tx['cash'] as num).toDouble(),
                  change: (tx['change'] as num).toDouble(),
                  items: items,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
