import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cashier/database/local_db.dart';

class ChartsTab extends StatefulWidget {
  const ChartsTab({super.key});

  @override
  State<ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends State<ChartsTab> {
  final LocalDatabase localDb = LocalDatabase();

  List<Map<String, dynamic>> monthlySales = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadChartData();
  }

  Future<void> loadChartData() async {
    try {
      final data = await localDb.getMonthlySales();
      setState(() {
        monthlySales = data;
      });

      // DEBUG PRINT
      for (var row in data) {
        print(row);
      }
    } catch (e) {
      print("Chart error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (monthlySales.isEmpty) {
      return const Center(
        child: Text("No sales data available"),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: monthlySales
                  .map((e) => (e['revenue'] ?? 0).toDouble())
                  .reduce((a, b) => a > b ? a : b) +
              10,
          barGroups: monthlySales.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;

            final revenue = (data['revenue'] ?? 0).toDouble();

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: revenue,
                  width: 22,
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= monthlySales.length) return const SizedBox();

                  return Text(
                    monthlySales[index]['month'] ?? '',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
