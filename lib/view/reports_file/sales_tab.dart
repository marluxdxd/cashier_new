import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:cashier/pdf/view_pdf_screen.dart';
import 'package:share_plus/share_plus.dart';

class SalesTab extends StatefulWidget {
  const SalesTab({super.key});

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  final supabase = Supabase.instance.client;

  List<String> availableMonths = [];
  bool isLoading = true;

  pw.Font? regularFont;
  pw.Font? boldFont;
  Uint8List? logoBytes;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await loadFonts();
    await loadLogo();
    await loadMonths();
  }

  // 🔹 LOAD FONTS (SUPPORTS ₱)
  Future<void> loadFonts() async {
    final regularData =
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData =
        await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');

    setState(() {
      regularFont = pw.Font.ttf(regularData);
      boldFont = pw.Font.ttf(boldData);
    });
  }

  // 🔹 LOAD LOGO IMAGE
  Future<void> loadLogo() async {
    final logoData =
        await rootBundle.load('assets/images/marhon.png');
    setState(() {
      logoBytes = logoData.buffer.asUint8List();
    });
  }

  // 🔹 FETCH MONTHS
  Future<void> loadMonths() async {
    final res = await supabase
        .from('transactions')
        .select('created_at')
        .order('created_at');

    final dates = (res as List)
        .map((e) => DateTime.parse(e['created_at']))
        .map((d) => DateFormat('yyyy-MM').format(d))
        .toSet()
        .toList();

    dates.sort((a, b) => b.compareTo(a));

    setState(() {
      availableMonths = dates;
      isLoading = false;
    });
  }

  String formatMonth(String yyyymm) {
    final date = DateTime.parse('$yyyymm-01');
    return DateFormat('MMMM yyyy').format(date);
  }

  Future<List<Map<String, dynamic>>> fetchMonthlyItems(String month) async {
    final res = await supabase.rpc(
      'get_monthly_transaction_items',
      params: {'month_param': month},
    );

    return List<Map<String, dynamic>>.from(res as List);
  }

  // 🔹 GENERATE PDF
  Future<File> generateMonthlyPDF(
    String month,
    List<Map<String, dynamic>> items,
  ) async {
    final pdf = pw.Document();

    final totalRevenue = items.fold<double>(
      0,
      (sum, i) => sum + (i['qty'] * (i['price'] as num).toDouble()),
    );

    final maxQtySold = items.map((i) => i['qty'] as int).reduce((a, b) => a > b ? a : b);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (logoBytes != null) 
                    pw.Image(pw.MemoryImage(logoBytes!), width: 60),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Monthly Sales Report',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 22,
                        ),
                      ),
                      pw.Text(
                        formatMonth(month),
                        style: pw.TextStyle(font: regularFont),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(),
              pw.Text(
                'Total Revenue: ₱${totalRevenue.toStringAsFixed(2)}',
                style: pw.TextStyle(font: regularFont),
              ),
              pw.Text(
                'Estimated Profit (30%): ₱${(totalRevenue * 0.3).toStringAsFixed(2)}',
                style: pw.TextStyle(font: regularFont),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Transaction Items',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 18,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.blueGrey100),
                    children: [
                      tableHeader('Product'),
                      tableHeader('Qty'),
                      tableHeader('Price'),
                      tableHeader('Subtotal'),
                    ],
                  ),
                  ...items.map((i) {
                    final subtotal =
                        i['qty'] * (i['price'] as num).toDouble();
                    return pw.TableRow(
                      children: [
                        tableCell(i['product_name']),
                        tableCell(i['qty'].toString(),
                            align: pw.TextAlign.right),
                        tableCell(
                          '₱${(i['price'] as num).toStringAsFixed(2)}',
                          align: pw.TextAlign.right,
                        ),
                        tableCell(
                          '₱${subtotal.toStringAsFixed(2)}',
                          align: pw.TextAlign.right,
                        ),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.blueGrey200),
                    children: [
                      tableHeader('TOTAL'),
                      pw.Container(),
                      pw.Container(),
                      tableHeader(
                        '₱${totalRevenue.toStringAsFixed(2)}',
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Product Sales Chart',
                style: pw.TextStyle(font: boldFont, fontSize: 18),
              ),
              pw.SizedBox(height: 10),

              // Drawing Bar Chart (Manually)
              pw.Container(
                height: 200,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: items.map((item) {
                    final qtySold = item['qty'] as int;
                    final barWidth = 30.0;
                    final maxHeight = 150.0;
                    final barHeight = (qtySold / maxQtySold) * maxHeight;

                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 10),
                      child: pw.Container(
                        width: barWidth,
                        height: barHeight,
                        color: PdfColors.blue,
                      ),
                    );
                  }).toList(),
                ),
              ),
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

  pw.Widget tableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: boldFont),
      ),
    );
  }

  pw.Widget tableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: regularFont),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: availableMonths.length,
      itemBuilder: (context, index) {
        final month = availableMonths[index];

        return Card(
          margin: const EdgeInsets.all(12),
          child: ListTile(
            title: Text(formatMonth(month)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  onPressed: () async {
                    final items = await fetchMonthlyItems(month);
                    final file = await generateMonthlyPDF(month, items);

                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewPDFScreen(pdfFile: file),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.blue),
                  onPressed: () async {
                    final items = await fetchMonthlyItems(month);
                    final file = await generateMonthlyPDF(month, items);

                    await Share.shareXFiles(
                      [XFile(file.path)],
                      text: 'Monthly Sales Report - ${formatMonth(month)}',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
