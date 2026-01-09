import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

class StockScreen2 extends StatefulWidget {
  const StockScreen2({super.key});

  @override
  State<StockScreen2> createState() => _StockScreen2State();
}

class _StockScreen2State extends State<StockScreen2> {
  late List<PlutoColumn> columns;
  late List<PlutoRow> rows;

  @override
  void initState() {
    super.initState();

    columns = [
      PlutoColumn(title: 'NO.', field: 'no', type: PlutoColumnType.number()),
      PlutoColumn(title: 'SUPPLIES', field: 'supplies', type: PlutoColumnType.text()),
      PlutoColumn(title: 'WHOLESALE PRICE', field: 'wholesale', type: PlutoColumnType.number()),
      PlutoColumn(title: 'PACK/PCS', field: 'pack', type: PlutoColumnType.text()),
      PlutoColumn(title: 'PRICE PER PCS', field: 'price', type: PlutoColumnType.number()),
      PlutoColumn(title: 'BY', field: 'by', type: PlutoColumnType.text()),
      PlutoColumn(title: 'KL', field: 'kl', type: PlutoColumnType.text()),
      PlutoColumn(title: 'TOTAL PURCHASE(PCS)', field: 'purchase', type: PlutoColumnType.number()),
      PlutoColumn(title: 'QUANTITY/PCS ACTUAL', field: 'actual', type: PlutoColumnType.number()),
      PlutoColumn(title: 'SOLD SUPPLIES', field: 'sold', type: PlutoColumnType.number()),
      PlutoColumn(title: 'INTEREST', field: 'interest', type: PlutoColumnType.number()),
      PlutoColumn(title: 'UNIT PRICE', field: 'unit', type: PlutoColumnType.number()),
      PlutoColumn(title: 'REMARKS', field: 'remarks', type: PlutoColumnType.text()),
    ];

    rows = [
      PlutoRow(cells: {
        'no': PlutoCell(value: 1),
        'supplies': PlutoCell(value: 'Sample Item'),
        'wholesale': PlutoCell(value: 1000),
        'pack': PlutoCell(value: '10 pcs'),
        'price': PlutoCell(value: 100),
        'by': PlutoCell(value: 'Pack'),
        'kl': PlutoCell(value: '-'),
        'purchase': PlutoCell(value: 10),
        'actual': PlutoCell(value: 10),
        'sold': PlutoCell(value: 3),
        'interest': PlutoCell(value: 20),
        'unit': PlutoCell(value: 120),
        'remarks': PlutoCell(value: 'OK'),
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Supplies Grid")),
      body: PlutoGrid(
        columns: columns,
        rows: rows,
        onLoaded: (event) {
          event.stateManager.setShowColumnFilter(true); // optional search/filter
        },
      ),
    );
  }
}
