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

class MonthlySales extends StatefulWidget {
  const MonthlySales({super.key});

  @override
  State<MonthlySales> createState() => _MonthlySalesState();
}

class _MonthlySalesState extends State<MonthlySales> {
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

  // 🔹 LOAD FONTS
  Future<void> loadFonts() async {
    final regularData = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');

    setState(() {
      regularFont = pw.Font.ttf(regularData);
      boldFont = pw.Font.ttf(boldData);
    });
  }

  // 🔹 LOAD LOGO
  Future<void> loadLogo() async {
    final logoData = await rootBundle.load('assets/images/marhon.png');
    setState(() {
      logoBytes = logoData.buffer.asUint8List();
    });
  }

  // 🔹 FETCH MONTHS FROM transactions
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

  // 🔹 FETCH ALL TRANSACTIONS AND ITEMS
  Future<List<Map<String, dynamic>>> fetchAllItemsMerged() async {
    final itemsRes = await supabase.from('transaction_items').select('*');
    final transactionsRes = await supabase.from('transactions').select('*');

    final items = List<Map<String, dynamic>>.from(itemsRes as List);
    final transactions = List<Map<String, dynamic>>.from(
      transactionsRes as List,
    );

    // Merge transaction data into items
    final merged = items.map((item) {
      final tx = transactions.firstWhere(
        (t) => t['id'] == item['transaction_id'],
        orElse: () => {},
      );
      item['transaction'] = tx;
      return item;
    }).toList();

    return merged;
  }

  // 🔹 FILTER ITEMS BY MONTH
  List<Map<String, dynamic>> filterItemsByMonth(
    List<Map<String, dynamic>> allItems,
    String month,
  ) {
    return allItems.where((item) {
      final createdAt = item['transaction']?['created_at'];
      if (createdAt == null) return false;
      final itemMonth = DateFormat(
        'yyyy-MM',
      ).format(DateTime.parse(createdAt.toString()));
      return itemMonth == month;
    }).toList();
  }

  // 🔹 GENERATE PDF WITH COMPACT MONTHLY CHART
  Future<File> generateMonthlyPDF(
    String month,
    List<Map<String, dynamic>> monthlyItems,
    List<Map<String, dynamic>> allItems,
  ) async {
    final pdf = pw.Document();

    // Helper: format numbers without .00
    String formatNumber(double value) {
      if (value == value.roundToDouble()) {
        return '${value.toInt()}';
      } else {
        return value.toStringAsFixed(2);
      }
    }

    // Total revenue for selected month
    final totalRevenue = monthlyItems.fold<double>(
      0,
      (sum, i) => sum + ((i['qty'] as int) * (i['retail_price'] as num).toDouble()),
    );

    // Chart: monthly totals for Jan–Dec
    final monthOrder = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    Map<String, double> monthlyTotals = {for (var m in monthOrder) m: 0.0};

    for (var item in allItems) {
      final createdAt = item['transaction']?['created_at'];
      if (createdAt == null) continue;
      final m = DateFormat('MMM').format(DateTime.parse(createdAt.toString()));
      if (monthlyTotals.containsKey(m)) {
        final subtotal =
            (item['qty'] as int) * (item['retail_price'] as num).toDouble();
        monthlyTotals[m] = monthlyTotals[m]! + subtotal;
      }
    }

    final maxMonthlyRevenue = monthlyTotals.values.isNotEmpty
        ? monthlyTotals.values.reduce((a, b) => a > b ? a : b)
        : 1.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
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
                        style: pw.TextStyle(font: boldFont, fontSize: 22),
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

              // REVENUE
              pw.Text(
                'Total Revenue: ₱${totalRevenue.toStringAsFixed(2)}',
                style: pw.TextStyle(font: regularFont),
              ),
              pw.Text(
                'Estimated Profit (30%): ₱${(totalRevenue * 0.3).toStringAsFixed(2)}',
                style: pw.TextStyle(font: regularFont),
              ),
              pw.SizedBox(height: 20),

              // PRODUCT TABLE
              pw.Text(
                'Transaction Items',
                style: pw.TextStyle(font: boldFont, fontSize: 18),
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
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey100,
                    ),
                    children: [
                      tableHeader('Product'),
                      tableHeader('Qty'),
                      tableHeader('Price'),
                      tableHeader('Subtotal'),
                    ],
                  ),
                  ...monthlyItems.map((i) {
                    final subtotal =
                        (i['qty'] as int) * (i['retail_price'] as num).toDouble();
                    return pw.TableRow(
                      children: [
                        tableCell(i['product_name'] ?? ''),
                        tableCell(
                          i['qty'].toString(),
                          align: pw.TextAlign.right,
                        ),
                        tableCell(
                          '₱${(i['retail_price'] as num).toStringAsFixed(2)}',
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
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey200,
                    ),
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

              // COMPACT MONTHLY CHART
              pw.SizedBox(height: 15),
              pw.Text(
                'Monthly Sales Chart',
                style: pw.TextStyle(font: boldFont, fontSize: 18),
              ),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                padding: const pw.EdgeInsets.all(4),
                height: 100, // compact height
                child: pw.Wrap(
                  spacing: 4,
                  alignment: pw.WrapAlignment.start,
                  crossAxisAlignment: pw.WrapCrossAlignment.end,
                  children: [
                    for (var m in monthOrder)
                      pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          // Numeric label (hide zero)
                          if (monthlyTotals[m]! > 0)
                            pw.Text(
                              formatNumber(monthlyTotals[m]!),
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: 7,
                              ),
                            ),
                          if (monthlyTotals[m]! > 0) pw.SizedBox(height: 1),
                          // Bar (height 0 if no sales)
                          pw.Container(
                            width: 10,
                            height:
                                (monthlyTotals[m]! / maxMonthlyRevenue) * 70,
                            color: PdfColors.blue,
                          ),
                          pw.SizedBox(height: 2),
                          // Month label
                          pw.Text(
                            m,
                            style: pw.TextStyle(font: regularFont, fontSize: 6),
                          ),
                        ],
                      ),
                  ],
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
    if (isLoading) return const Center(child: CircularProgressIndicator());

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
                    final allItems = await fetchAllItemsMerged();
                    final monthlyItems = filterItemsByMonth(allItems, month);
                    final file = await generateMonthlyPDF(
                      month,
                      monthlyItems,
                      allItems,
                    );

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
                    final allItems = await fetchAllItemsMerged();
                    final monthlyItems = filterItemsByMonth(allItems, month);
                    final file = await generateMonthlyPDF(
                      month,
                      monthlyItems,
                      allItems,
                    );

                    await Share.shareXFiles([
                      XFile(file.path),
                    ], text: 'Monthly Sales Report - ${formatMonth(month)}');
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
