import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

Future<File> generateMonthlyPDF(String month, int revenue, int profit) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Monthly Report: $month",
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),

            pw.Text("Revenue: ₱$revenue",
                style: pw.TextStyle(fontSize: 16)),
            pw.Text("Profit: ₱$profit",
                style: pw.TextStyle(fontSize: 16)),
          ],
        );
      },
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final file = File("${dir.path}/sales_$month.pdf");

  await file.writeAsBytes(await pdf.save());
  return file;
}
