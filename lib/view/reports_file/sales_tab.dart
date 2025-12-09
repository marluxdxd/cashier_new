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
  List<Map<String, dynamic>> monthlySales = [];
  final localDb = LocalDatabase();

  @override
  void initState() {
    super.initState();
    loadMonthlySales();
  }

  Future<void> loadMonthlySales() async {
    // Load monthly revenue + profit from local DB
    final data = await localDb.getMonthlySales();

    setState(() {
      monthlySales = data;
    });
  }

  String formatMonth(String yyyymm) {
    final date = DateTime.parse("$yyyymm-01");
    return DateFormat("MMM yyyy").format(date);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: monthlySales.length,
      itemBuilder: (context, index) {
        final data = monthlySales[index];
        final monthLabel = formatMonth(data["month"]);

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // MONTH + REVENUE
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthLabel,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text("Revenue: ₱${data['revenue']}"),
                    ],
                  ),

                  // PROFIT
                  Column(
                    children: [
                      Text(
                        "Profit",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text("₱${data['profit']}"),
                    ],
                  ),

                  // PDF ICON
                  IconButton(
                    icon: Icon(Icons.picture_as_pdf, color: Colors.red),
                    onPressed: () async {
                      // Generate PDF file
                      final file = await generateMonthlyPDF(
                        data["month"],
                        data["revenue"].toInt(),
                        data["profit"],
                      );

                      // Open PDF viewer screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ViewPDFScreen(pdfFile: file),
                        ),
                      );
                    },
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

