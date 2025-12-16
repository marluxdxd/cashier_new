import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/pdf/view_pdf_screen.dart';
import 'package:cashier/pdf/generate_monthly_pdf.dart';

class SalesTab extends StatefulWidget {
  const SalesTab({super.key});

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  final LocalDatabase localDb = LocalDatabase();

  List<Map<String, dynamic>> monthlySales = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMonthlySales();
  }

  Future<void> loadMonthlySales() async {
    try {
      final data = await localDb.getMonthlySales();
      setState(() => monthlySales = data);
    } catch (e) {
      debugPrint("SalesTab error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  String formatMonth(String yyyymm) {
    final date = DateTime.parse("$yyyymm-01");
    return DateFormat("MMM yyyy").format(date);
  }

  double calculateProfit(double revenue) => revenue * 0.30;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (monthlySales.isEmpty) {
      return const Center(child: Text("No sales data"));
    }

    return ListView.builder(
      itemCount: monthlySales.length,
      itemBuilder: (context, index) {
        final data = monthlySales[index];

        final String month = data['month'] ?? '';
        final double revenue =
            (data['revenue'] as num?)?.toDouble() ?? 0.0;
        final double profit = calculateProfit(revenue);

        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text(formatMonth(month)),
            subtitle: Text("Revenue: ₱${revenue.toStringAsFixed(2)}"),
            trailing: IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              onPressed: () async {
                final items = await localDb.getMonthlyItems(month); // Get all items for the month
               final file = await generateMonthlyPDF(month, revenue, items);

                if (!mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ViewPDFScreen(pdfFile: file),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
