import 'package:flutter/material.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/services/transaction_service.dart';

class PaymentsTab extends StatefulWidget {
  const PaymentsTab({super.key});

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  final LocalDatabase localDb = LocalDatabase();
  final TransactionService transactionService = TransactionService();

  List<Map<String, dynamic>> payments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPayments();
  }

  Future<void> loadPayments() async {
    try {
      setState(() => isLoading = true);

      List<Map<String, dynamic>> allPayments = [];

      // -------------------
      // Fetch online payments from Supabase
      // -------------------
      try {
        final onlinePayments = await transactionService.fetchTransactions();
        allPayments.addAll(onlinePayments.map((t) {
          return {
            'id': t['id'],
            'total': t['total'],
            'cash': t['cash'],
            'change': t['change'],
            'created_at': t['created_at'],
            'is_synced': 1, // online data
          };
        }));
      } catch (_) {
        debugPrint("Supabase offline, loading local only");
      }

      // -------------------
      // Fetch offline payments from local SQLite
      // -------------------
      final offlinePayments = await localDb.getAllTransactions();
      allPayments.addAll(offlinePayments.map((t) {
        return {
          'id': t['id'],
          'total': t['total'],
          'cash': t['cash'],
          'change': t['change'],
          'created_at': t['created_at'],
          'is_synced': t['is_synced'] ?? 0,
        };
      }));

      // Sort by date descending
      allPayments.sort((a, b) => b['created_at'].compareTo(a['created_at']));

      setState(() => payments = allPayments);
    } catch (e) {
      debugPrint("Error loading payments: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (payments.isEmpty) return const Center(child: Text("No payments found"));

    return ListView.builder(
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final p = payments[index];
        final isOffline = (p['is_synced'] ?? 0) == 0;

        return Card(
          margin: const EdgeInsets.all(8),
          color: isOffline ? Colors.grey[100] : Colors.white,
          child: ListTile(
            leading: isOffline
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            title: Text("Transaction ${p['id']}"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total: ₱${(p['total'] as num?)?.toStringAsFixed(2) ?? '0.00'}"),
                Text("Cash: ₱${(p['cash'] as num?)?.toStringAsFixed(2) ?? '0.00'}"),
                Text("Change: ₱${(p['change'] as num?)?.toStringAsFixed(2) ?? '0.00'}"),
                Text("Date: ${p['created_at'] ?? ''}"),
              ],
            ),
          ),
        );
      },
    );
  }
}
