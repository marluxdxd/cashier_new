import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/pdf/view_pdf_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

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
      debugPrint("Error loading sales: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  String formatMonth(String yyyymm) {
    final date = DateTime.parse("$yyyymm-01");
    return DateFormat("MMM yyyy").format(date);
  }

  double calculateProfit(double revenue) => revenue * 0.3;

  Future<File> generateMonthlyPDF(
      String month, double revenue, List<Map<String, dynamic>> items) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Monthly Sales Report",
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text("Month: $month"),
              pw.Text("Revenue: ₱${revenue.toStringAsFixed(2)}"),
              pw.Text("Profit: ₱${calculateProfit(revenue).toStringAsFixed(2)}"),
              pw.SizedBox(height: 10),
              pw.Text("Items Purchased:"),
              pw.SizedBox(height: 5),
              ...items.map((i) {
                final name = i['product_name'] ?? 'Unknown';
                final qty = i['qty'] ?? 0;
                final price = i['price'] ?? 0.0;
                final subtotal = qty * price;
                return pw.Text("$name x$qty - ₱${subtotal.toStringAsFixed(2)}");
              }),
            ],
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/sales_$month.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (monthlySales.isEmpty) return const Center(child: Text("No sales data"));

    return ListView.builder(
      itemCount: monthlySales.length,
      itemBuilder: (context, index) {
        final data = monthlySales[index];
        final month = data['month']?.toString() ?? '';
        final revenue = (data['revenue'] as num?)?.toDouble() ?? 0.0;

        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text(formatMonth(month)),
            subtitle: Text("Revenue: ₱${revenue.toStringAsFixed(2)}"),
            trailing: IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              onPressed: () async {
                final items = await localDb.getMonthlyItems(month);
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
