import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cashier/pdf/view_pdf_screen2.dart';

class StockScreen2 extends StatefulWidget {
  const StockScreen2({super.key});

  @override
  State<StockScreen2> createState() => _StockScreen2State();
}

class _StockScreen2State extends State<StockScreen2> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> stockItems = [];
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
    await fetchStockItems();
    await loadReportQueue();
  }

  Future<void> loadFonts() async {
    final regularData =
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');

    if (!mounted) return;
    setState(() {
      regularFont = pw.Font.ttf(regularData);
      boldFont = pw.Font.ttf(boldData);
    });
  }

  Future<void> fetchStockItems() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final res = await supabase.from('products').select('*');
      final items = List<Map<String, dynamic>>.from(res as List);

      // Compute all fields based on AddProductPage logic
      final computed = items.map((item) {
        final retailPrice =
            double.tryParse(item['retail_price']?.toString() ?? '0') ?? 0;
        final byPieces = int.tryParse(item['byPieces']?.toString() ?? '1') ?? 1;
        final stock = int.tryParse(item['stock']?.toString() ?? '0') ?? 0;
        final soldSupplies =
            int.tryParse(item['soldSupplies']?.toString() ?? '0') ?? 0;
        final isPromo = item['isPromo'] ?? false;
        final otherQty = int.tryParse(item['otherQty']?.toString() ?? '0') ?? 0;

        final pricePerPiece = byPieces > 0 ? retailPrice / byPieces : 0;
        final total = isPromo ? otherQty * retailPrice : stock * retailPrice;
        final interest = isPromo
            ? (otherQty * retailPrice - retailPrice)
            : (retailPrice - pricePerPiece);

        item['retail_price'] = retailPrice;
        item['by_pieces'] = byPieces;
        item['price_per_piece'] = pricePerPiece;
        item['total'] = total;
        item['actual_stock'] = stock;
        item['sold_supplies'] = soldSupplies;
        item['interest'] = interest;
        item['unit_price'] = retailPrice;

        return item;
      }).toList();

      if (!mounted) return;
      setState(() {
        stockItems = computed;
      });
    } catch (e) {
      debugPrint("Error fetching stock items: $e");
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> get filteredStockItems {
    if (startDate == null || endDate == null) return stockItems;

    return stockItems.where((item) {
      final createdAt = item['created_at'];
      if (createdAt == null) return false;
      final date = DateTime.parse(createdAt.toString());
      return !date.isBefore(startDate!) && !date.isAfter(endDate!);
    }).toList();
  }

  Future<File> generatePDF(DateTime start, DateTime end) async {
    final filtered = filteredStockItems;
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Text('Stock Report',
              style: pw.TextStyle(font: boldFont, fontSize: 22)),
          pw.SizedBox(height: 8),
          pw.Text(
            '${DateFormat('MMM dd, yyyy').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}',
            style: pw.TextStyle(font: regularFont, fontSize: 12),
          ),
          pw.SizedBox(height: 10),
          _buildPDFTable(filtered),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/stock_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildPDFTable(List<Map<String, dynamic>> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(3), // Product Name
        1: pw.FlexColumnWidth(2), // Retail Price
        2: pw.FlexColumnWidth(1), // By Pieces
        3: pw.FlexColumnWidth(2), // Price Per Piece
        4: pw.FlexColumnWidth(2), // Total
        5: pw.FlexColumnWidth(2), // Actual Stock
        6: pw.FlexColumnWidth(2), // Sold Supplies
        7: pw.FlexColumnWidth(2), // Interest
        8: pw.FlexColumnWidth(2), // Unit Price
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
          children: [
            _pdfHeader('Product Name'),
            _pdfHeader('Retail Price'),
            _pdfHeader('By Pieces'),
            _pdfHeader('Price Per Piece'),
            _pdfHeader('Total'),
            _pdfHeader('Actual Stock'),
            _pdfHeader('Sold Supplies'),
            _pdfHeader('Interest'),
            _pdfHeader('Unit Price'),
          ],
        ),
        for (var item in items)
          pw.TableRow(
            children: [
              _pdfCell(item['name'] ?? ''),
              _pdfCell('₱${(item['retail_price'] ?? 0).toStringAsFixed(2)}'),
              _pdfCell('${item['by_pieces']}'),
              _pdfCell('₱${(item['price_per_piece'] ?? 0).toStringAsFixed(2)}'),
              _pdfCell('₱${(item['total'] ?? 0).toStringAsFixed(2)}'),
              _pdfCell('${item['actual_stock']}'),
              _pdfCell('${item['sold_supplies']}'),
              _pdfCell('₱${(item['interest'] ?? 0).toStringAsFixed(2)}'),
              _pdfCell('₱${(item['unit_price'] ?? 0).toStringAsFixed(2)}'),
            ],
          ),
      ],
    );
  }

  pw.Widget _pdfHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(font: boldFont, fontSize: 10)),
    );
  }

  pw.Widget _pdfCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(font: regularFont, fontSize: 10)),
    );
  }

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
                if (picked != null && mounted) setState(() => startDate = picked);
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
                if (picked != null && mounted) setState(() => endDate = picked);
              },
              child: Text(endDate == null
                  ? "End Date"
                  : "To: ${DateFormat('yyyy-MM-dd').format(endDate!)}"),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.green),
            onPressed: () {
              if (startDate != null && endDate != null && mounted) {
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
      if (!mounted) return;
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
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Product Name')),
                      DataColumn(label: Text('Retail Price'), numeric: true),
                      DataColumn(label: Text('By Pieces'), numeric: true),
                      DataColumn(label: Text('Price Per Piece'), numeric: true),
                      DataColumn(label: Text('Total'), numeric: true),
                      DataColumn(label: Text('Actual Stock'), numeric: true),
                      DataColumn(label: Text('Sold Supplies'), numeric: true),
                      DataColumn(label: Text('Interest'), numeric: true),
                      DataColumn(label: Text('Unit Price'), numeric: true),
                    ],
                    rows: filteredStockItems.map((item) {
                      return DataRow(
                        cells: [
                          DataCell(Text(item['name'] ?? '')),
                          DataCell(Text('₱${(item['retail_price'] ?? 0).toStringAsFixed(2)}')),
                          DataCell(Text('${item['by_pieces']}')),
                          DataCell(Text('₱${(item['price_per_piece'] ?? 0).toStringAsFixed(2)}')),
                          DataCell(Text('₱${(item['total'] ?? 0).toStringAsFixed(2)}')),
                          DataCell(Text('${item['actual_stock']}')),
                          DataCell(Text('${item['sold_supplies']}')),
                          DataCell(Text('₱${(item['interest'] ?? 0).toStringAsFixed(2)}')),
                          DataCell(Text('₱${(item['unit_price'] ?? 0).toStringAsFixed(2)}')),
                        ],
                      );
                    }).toList(),
                  ),
                )
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
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                              onPressed: () async {
                                final file = await generatePDF(start, end);
                                if (!mounted) return;
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ViewPDFScreen2(pdfFile: file)));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.blue),
                              onPressed: () async {
                                final file = await generatePDF(start, end);
                                if (!mounted) return;
                                await Share.shareXFiles([XFile(file.path)],
                                    text:
                                        'Stock Report: ${DateFormat('MMM dd, yyyy').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () {
                                if (!mounted) return;
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