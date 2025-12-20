import 'package:cashier/database/local_db.dart';
import 'package:flutter/material.dart';

class DebugDbScreen extends StatefulWidget {
  const DebugDbScreen({super.key});

  @override
  State<DebugDbScreen> createState() => _DebugDbScreenState();
}

class _DebugDbScreenState extends State<DebugDbScreen> {
  final LocalDatabase db = LocalDatabase();

  bool isLoading = true;
  List<String> tableNames = [];
  Map<String, List<Map<String, dynamic>>> tableRows = {};

  @override
  void initState() {
    super.initState();
    loadTables();
  }

  Future<void> loadTables() async {
    setState(() {
      isLoading = true;
    });

    try {
      final names = await db.getAllTableNames();
      Map<String, List<Map<String, dynamic>>> rows = {};

      for (var table in names) {
        final tableData = await db.getAllRows(table);
        rows[table] = tableData;
      }

      if (!mounted) return;

      setState(() {
        tableNames = names;
        tableRows = rows;
      });
    } catch (e) {
      print("Error loading tables: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget buildDataTable(String tableName) {
    final rows = tableRows[tableName] ?? [];
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          "No data",
          style: TextStyle(fontSize: 10),
        ),
      );
    }

    // Extract all column names
    final columns = rows.first.keys.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 8,
        dataRowHeight: 28,
        headingRowHeight: 32,
        columns: columns
            .map((col) => DataColumn(
                  label: Text(
                    col,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ))
            .toList(),
        rows: rows
            .map((row) => DataRow(
                  cells: columns
                      .map((col) => DataCell(
                            Text(
                              row[col]?.toString() ?? '',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ))
                      .toList(),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Debug SQLite DB"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: tableNames.length,
              itemBuilder: (_, index) {
                final table = tableNames[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ExpansionTile(
                    title: Text(
                      table,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: buildDataTable(table),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
