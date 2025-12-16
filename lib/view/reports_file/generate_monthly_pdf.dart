import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

Future<File> generateMonthlyPDF(
  String month,
  double revenue,
  List<Map<String, dynamic>> items,
) async {
  final pdf = pw.Document();

  // Calculate profit (30% of revenue) for display
  final double profit = revenue * 0.3;

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
            pw.Text("Profit: ₱${profit.toStringAsFixed(2)}"),
            pw.SizedBox(height: 10),
            pw.Text("Items Purchased:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            // List items with quantity, price, subtotal
            pw.ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final name = item['product_name'] ?? 'Unknown';
                final qty = item['qty'] ?? 0;
                final price = (item['price'] ?? 0.0).toDouble();
                final subtotal = qty * price;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Text("$name x$qty - ₱${subtotal.toStringAsFixed(2)}"),
                );
              },
            ),
          ],
        );
      },
    ),
  );

  // Save PDF file
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/sales_$month.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}
