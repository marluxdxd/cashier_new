import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cashier/database/local_db.dart';

// Data models
class TransactionItem {
  final int id;
  final int productId;
  final String productName;
  final int qty;
  final double price;
  final bool isPromo;
  final int otherQty;

  TransactionItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.price,
    required this.isPromo,
    required this.otherQty,
  });

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['item_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      qty: map['qty'],
      price: map['price'],
      isPromo: map['is_promo'] == 1,
      otherQty: map['other_qty'] ?? 0,
    );
  }
}

class TransactionHeader {
  final int id;
  final double cash;
  final double change;
  final String createdAt;
  final List<TransactionItem> items;

  TransactionHeader({
    required this.id,
    required this.cash,
    required this.change,
    required this.createdAt,
    required this.items,
  });
}

// Screen
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final LocalDatabase localDb = LocalDatabase();
  List<TransactionHeader> transactions = [];

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final rawData = await localDb.getTransactionsWithItems();

    Map<int, List<TransactionItem>> tempMap = {};

    // Group items by transaction_id
    for (var row in rawData) {
      final itemId = row['item_id'];
      if (itemId != null) {
        final item = TransactionItem.fromMap(row);
        tempMap.putIfAbsent(row['transaction_id'], () => []);
        tempMap[row['transaction_id']]!.add(item);
      }
    }

    List<TransactionHeader> headers = [];
    Set<int> processed = {};

    for (var row in rawData) {
      final trxId = row['transaction_id'];
      if (processed.contains(trxId)) continue;

      headers.add(TransactionHeader(
        id: trxId,
        cash: row['cash'],
        change: row['change'],
        createdAt: row['created_at'],
        items: tempMap[trxId] ?? [],
      ));

      processed.add(trxId);
    }

    setState(() {
      transactions = headers;
    });
  }

  void clearAll() async {
    for (var t in transactions) {
      await localDb.deleteTransaction(t.id);
      for (var item in t.items) {
        await localDb.deleteTransactionItem(item.id);
      }
    }
    setState(() {
      transactions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Transaction History"),
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text("Clear all history?"),
                  content: Text("This will delete all transactions."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        clearAll();
                        Navigator.pop(context);
                      },
                      child: Text("Confirm"),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: transactions.isEmpty
          ? Center(child: Text("No transactions yet."))
          : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final t = transactions[index];
                final createdAt = DateFormat('MMM d, yyyy').format(DateTime.parse(t.createdAt));

                return Card(
                  margin: EdgeInsets.all(8),
                  child: ExpansionTile(
                    title: Text("Transaction #${t.id}"),
                    subtitle: Text("Cash: ₱${t.cash} | Change: ₱${t.change} | $createdAt"),
                    children: t.items.map((item) {
                      return ListTile(
                        title: Text(item.productName),
                        subtitle: Text(
                            "Qty: ${item.qty} | Price: ₱${item.price.toStringAsFixed(2)} | Total: ₱${(item.price * item.qty).toStringAsFixed(2)}"),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}
