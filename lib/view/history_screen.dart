import 'package:cashier/services/transaction_service.dart';
import 'package:cashier/view/history_file/history_screen_offline.dart';
import 'package:cashier/view/history_file/history_screen_online.dart';
import 'package:flutter/material.dart';


class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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
  setState(() => isLoading = true);
  try {
    final trx = await transactionService.fetchAllTransactions();
    setState(() => transactions = trx);

    for (var t in trx) {
      final items = await transactionService.fetchAllTransactionItems(t['id']);
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
    return DefaultTabController(
      length: 2,   // 3 TABS
      child: Scaffold(
        appBar: AppBar(
          title: Text("Reports"),
          bottom: TabBar(
            labelColor: Colors.grey,
            unselectedLabelColor: Colors.black,
            indicatorColor: Colors.red,
            tabs: const [
              Tab(icon: Icon(Icons.shopping_bag), text: "Online"),
              Tab(icon: Icon(Icons.payments), text: "Offline"),
       
            ],
          ),
        ),

        body: const TabBarView(
          children: [
            HistoryScreenOnline(),
            HistoryScreenOffline(),
            
          ],
        ),
      ),
    );
  }
}



