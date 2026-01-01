import 'dart:convert';
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
import 'package:shared_preferences/shared_preferences.dart';

class SetSaleDateTab extends StatefulWidget {
  const SetSaleDateTab({super.key});

  @override
  State<SetSaleDateTab> createState() => _SetSaleDateTabState();
}

class _SetSaleDateTabState extends State<SetSaleDateTab> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> mergedItems = [];
  List<Map<String, DateTime>> reportQueue = [];
  bool isLoading = true;

  DateTime? startDate;
  DateTime? endDate;

  pw.Font? regularFont;
  pw.Font? boldFont;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await loadFonts();
    await fetchAndMergeItems();
    await loadReportQueue();
  }

  // Load custom fonts
  Future<void> loadFonts() async {
    final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');

    setState(() {
      regularFont = pw.Font.ttf(regularData);
      boldFont = pw.Font.ttf(boldData);
    });
  }

  // Fetch transactions & items, merge them
  Future<void> fetchAndMergeItems() async {
    setState(() => isLoading = true);
    try {
      final transactionsRes = await supabase
          .from('transactions')
          .select('*')
          .order('created_at', ascending: false);
      final itemsRes = await supabase.from('transaction_items').select('*');

      final transactions = List<Map<String, dynamic>>.from(transactionsRes as List);
      final items = List<Map<String, dynamic>>.from(itemsRes as List);

      mergedItems = items.map((item) {
        final tx = transactions.firstWhere(
          (t) => t['id'].toString() == item['transaction_id'].toString(),
          orElse: () => {},
        );
        item['transaction'] = tx;
        return item;
      }).toList();
    } catch (e) {
      debugPrint("Error fetching payments: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Filter items by date range
  List<Map<String, dynamic>> filterItemsByDate(DateTime start, DateTime end) {
    return mergedItems.where((item) {
      final createdAt = item['transaction']?['created_at'];
      if (createdAt == null) return false;
      final date = DateTime.parse(createdAt.toString());
      return !date.isBefore(start) && !date.isAfter(end.add(const Duration(days: 1)));
    }).toList();
  }

  // Generate single PDF for all items in range
  Future<File> generatePDF(DateTime start, DateTime end) async {
  final filteredItems = filterItemsByDate(start, end);
  final pdf = pw.Document();

  // Grand total
  double grandTotal = filteredItems.fold(0.0, (sum, i) {
    return sum + ((i['qty'] as num) * (i['price'] as num));
  });

  // Product sales totals for chart
  final productTotals = <String, double>{};
  for (var item in filteredItems) {
    final product = item['product_name'] ?? 'Unknown';
    final subtotal = (item['qty'] as num) * (item['price'] as num);
    productTotals[product] = (productTotals[product] ?? 0) + subtotal;
  }

  // Get max for scaling chart
  final maxProductTotal = productTotals.values.isNotEmpty
      ? productTotals.values.reduce((a, b) => a > b ? a : b)
      : 1.0;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return [
          pw.Text('Payments Report',
              style: pw.TextStyle(font: boldFont, fontSize: 22)),
          pw.SizedBox(height: 8),
          pw.Text(
            '${DateFormat('MMM dd, yyyy').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}',
            style: pw.TextStyle(font: regularFont),
          ),
          pw.Divider(),
          _buildTable(filteredItems),
          pw.Divider(),
          pw.Text(
            'Grand Total: ₱${grandTotal.toStringAsFixed(2)}',
            style: pw.TextStyle(font: boldFont, fontSize: 14),
          ),
          pw.SizedBox(height: 20),

          // Product Sales Chart
      pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    // Chart Title
  
    pw.SizedBox(height: 12),
  pw.Text(
      'Product Sales Chart',
      style: pw.TextStyle(font: boldFont, fontSize: 16),
    ),
    // Chart Container with border and background
    pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey800, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
        color: PdfColors.grey200, // subtle background
      ),
      height: 150,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly, // evenly space bars
        children: productTotals.entries.map((entry) {
          final barHeight = (entry.value / maxProductTotal) * 100;

          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              // Bar with rounded corners
              pw.Container(
                width: 24,
                height: barHeight,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.grey700, width: 0.5),
                ),
              ),
              pw.SizedBox(height: 6),

              // Label
              pw.Container(
                width: 28,
                child: pw.Text(
                  entry.key,
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    ),
  ],
)

        ];
      },
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final file = File(
      '${dir.path}/payments_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}


  // Build table with transaction id, product, qty, price, subtotal, date
  pw.Widget _buildTable(List<Map<String, dynamic>> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Transaction ID
        1: const pw.FlexColumnWidth(3), // Product
        2: const pw.FlexColumnWidth(1), // Qty
        3: const pw.FlexColumnWidth(2), // Price
        4: const pw.FlexColumnWidth(2), // Subtotal
        5: const pw.FlexColumnWidth(2), // Date
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
          children: [
            _tableHeader('Transaction ID'),
            _tableHeader('Product'),
            _tableHeader('Qty'),
            _tableHeader('Price'),
            _tableHeader('Subtotal'),
            _tableHeader('Date'),
          ],
        ),
        for (var item in items)
          pw.TableRow(
            children: [
              _tableCell('${item['transaction']?['id'] ?? ''}'),
              _tableCell(item['product_name'] ?? ''),
              _tableCell('${item['qty']}', align: pw.TextAlign.right),
              _tableCell('₱${(item['price'] as num).toStringAsFixed(2)}',
                  align: pw.TextAlign.right),
              _tableCell(
                  '₱${((item['qty'] as num) * (item['price'] as num)).toStringAsFixed(2)}',
                  align: pw.TextAlign.right),
              _tableCell(item['transaction']?['created_at']?.toString().split(' ')[0] ?? ''),
            ],
          ),
      ],
    );
  }

  pw.Widget _tableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(font: boldFont), textAlign: align),
    );
  }

  pw.Widget _tableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(font: regularFont), textAlign: align),
    );
  }

  // Date filter UI + add to queue
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
                if (picked != null) setState(() => startDate = picked);
              },
              child: Text(startDate == null
                  ? "Start Date"
                  : "From: ${DateFormat('yyyy-MM-dd').format(startDate!)}"),
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
                if (picked != null) setState(() => endDate = picked);
              },
              child: Text(endDate == null
                  ? "End Date"
                  : "To: ${DateFormat('yyyy-MM-dd').format(endDate!)}"),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.green),
            onPressed: () {
              if (startDate != null && endDate != null) {
                setState(() {
                  reportQueue.add({'startDate': startDate!, 'endDate': endDate!});
                });
                saveReportQueue();
              }
            },
          ),
        ],
      ),
    );
  }

  // SharedPreferences for report queue
  Future<void> saveReportQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final json = reportQueue
        .map((e) => {
              'startDate': e['startDate']!.toIso8601String(),
              'endDate': e['endDate']!.toIso8601String(),
            })
        .toList();
    await prefs.setString('reportQueue', jsonEncode(json));
  }

  Future<void> loadReportQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('reportQueue');
    if (jsonString != null) {
      final decoded = jsonDecode(jsonString) as List;
      setState(() {
        reportQueue = decoded.map((e) {
          return {
            'startDate': DateTime.parse(e['startDate']),
            'endDate': DateTime.parse(e['endDate']),
          };
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        dateFilterBar(),
        Expanded(
          child: reportQueue.isEmpty
              ? const Center(child: Text("No reports queued. Select date range."))
              : ListView.builder(
                  itemCount: reportQueue.length,
                  itemBuilder: (context, index) {
                    final report = reportQueue[index];
                    final start = report['startDate']!;
                    final end = report['endDate']!;
                    return Card(
                      margin: const EdgeInsets.all(12),
                      child: ListTile(
                        title: Text(
                            'Report: ${DateFormat('MMM dd, yyyy').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf,
                                  color: Colors.red),
                              onPressed: () async {
                                final file = await generatePDF(start, end);
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
                                final file = await generatePDF(start, end);
                                await Share.shareXFiles([XFile(file.path)],
                                    text:
                                        'Payments Report: ${DateFormat('MMM dd, yyyy').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  reportQueue.removeAt(index);
                                });
                                saveReportQueue();
                              },
                            ),
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
