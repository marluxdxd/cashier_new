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

  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    loadPayments();
  }

  // =========================
  // LOAD PAYMENTS (ONLINE + OFFLINE)
  // =========================
  Future<void> loadPayments() async {
    try {
      setState(() => isLoading = true);

      List<Map<String, dynamic>> allPayments = [];

      // -------------------
      // ONLINE PAYMENTS (Supabase)
      // -------------------
      try {
        final onlinePayments =
            await transactionService.fetchAllTransactions(
          startDate: startDate,
          endDate: endDate,
        );

        allPayments.addAll(onlinePayments.map((t) {
          return {
            'id': t['id'],
            'total': t['total'],
            'cash': t['cash'],
            'change': t['change'],
            'created_at': t['created_at'],
            'is_synced': t['is_synced'] ?? 1,
          };
        }));
      } catch (e) {
        debugPrint("Supabase offline, loading local only");
      }

      // -------------------
      // OFFLINE PAYMENTS (SQLite)
      // -------------------
      final offlinePayments = await localDb.getAllTransactions();

      final filteredOffline = offlinePayments.where((t) {
        if (t['is_synced'] != 0) return false;

        final date = DateTime.parse(t['created_at']);

        if (startDate != null && date.isBefore(startDate!)) return false;
        if (endDate != null &&
            date.isAfter(endDate!.add(const Duration(days: 1)))) return false;

        return true;
      }).toList();

      allPayments.addAll(filteredOffline.map((t) {
        return {
          'id': t['id'],
          'total': t['total'],
          'cash': t['cash'],
          'change': t['change'],
          'created_at': t['created_at'],
          'is_synced': 0,
        };
      }));

      // -------------------
      // SORT BY DATE DESC
      // -------------------
      allPayments.sort((a, b) =>
          b['created_at'].compareTo(a['created_at']));

      setState(() => payments = allPayments);
    } catch (e) {
      debugPrint("Error loading payments: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // =========================
  // DATE FILTER UI
  // =========================
  Widget dateFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => startDate = picked);
                  loadPayments();
                }
              },
              child: Text(
                startDate == null
                    ? "Start Date"
                    : "From: ${startDate!.toLocal().toString().split(' ')[0]}",
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: endDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => endDate = picked);
                  loadPayments();
                }
              },
              child: Text(
                endDate == null
                    ? "End Date"
                    : "To: ${endDate!.toLocal().toString().split(' ')[0]}",
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: "Clear Filter",
            onPressed: () {
              setState(() {
                startDate = null;
                endDate = null;
              });
              loadPayments();
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (payments.isEmpty) {
      return Column(
        children: [
          dateFilterBar(),
          const Expanded(
            child: Center(child: Text("No payments found")),
          ),
        ],
      );
    }

    return Column(
      children: [
        dateFilterBar(),
        Expanded(
          child: ListView.builder(
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Offline",
                            style: TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        )
                      : null,
                  title: Text("Transaction ${p['id']}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "Total: ₱${(p['total'] as num).toStringAsFixed(2)}"),
                      Text(
                          "Cash: ₱${(p['cash'] as num).toStringAsFixed(2)}"),
                      Text(
                          "Change: ₱${(p['change'] as num).toStringAsFixed(2)}"),
                      Text("Date: ${p['created_at']}"),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
