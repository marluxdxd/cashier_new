import 'package:flutter/material.dart';
import 'package:cashier/class/productclass.dart';
import 'package:cashier/class/posrowclass.dart';
import 'package:cashier/widget/productbottomsheet.dart';
import 'package:cashier/widget/qtybottomsheet.dart';
import 'package:cashier/widget/sukli.dart';
import 'package:cashier/widget/appdrawer.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<POSRow> rows = [POSRow()]; // Start with one empty row
  TextEditingController customerCashController = TextEditingController();

  //-----------------Add Empty Row---------------------------------
  void _addEmptyRow() {
    setState(() {
      rows.add(POSRow());
    });
  }

  //-----------------Compute Total Bill---------------------------
  double get totalBill {
    double total = 0;
    for (var row in rows) {
      if (row.product != null) total += row.product!.price * row.qty;
    }
    return total;
  }

  //-----------------Build Each POS Row---------------------------
  Widget buildRow(POSRow row, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Product
          Expanded(
            flex: 6,
            child: InkWell(
              onTap: () async {
                final selectedProduct = await showModalBottomSheet<Productclass>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => Productbottomsheet(),
                );
                if (selectedProduct != null) {
                  setState(() {
                    row.product = selectedProduct;
                    if (row == rows.last) _addEmptyRow();
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(row.product?.name ?? "Select Product"),
              ),
            ),
          ),

          SizedBox(width: 8),

          // Quantity
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () async {
                final qty = await showModalBottomSheet<int>(
                  context: context,
                  builder: (_) => Qtybottomsheet(),
                );
                if (qty != null) {
                  setState(() {
                    row.qty = qty;
                    if (row == rows.last) _addEmptyRow();
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(row.qty == 0 ? "Qty" : row.qty.toString()),
              ),
            ),
          ),

          SizedBox(width: 8),

          // Row total
          Text(
            row.product != null
                ? "₱${(row.product!.price * row.qty).toStringAsFixed(2)}"
                : "₱0.00",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          // Delete button
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              setState(() {
                rows.removeAt(index);
                if (rows.isEmpty) _addEmptyRow();
              });
            },
          ),
        ],
      ),
    );
  }

  //------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.0,
        title: Text('Sari2x Store'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.search, color: Colors.black, size: 30),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.notifications, color: Colors.black, size: 30),
          ),
        ],
      ),
      drawer: Appdrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // CART ROWS
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, index) => buildRow(rows[index], index),
              ),
            ),

            SizedBox(height: 20),

            // TOTAL BILL
            Container(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 5,
                    color: Colors.grey.withOpacity(0.2),
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Bill:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "₱${totalBill.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // CUSTOMER CASH
            TextField(
              controller: customerCashController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Customer Cash",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                double cash = double.tryParse(customerCashController.text) ?? 0;

                if (cash < totalBill) {
                  print("Cash is not enough yet.");
                  return;
                }

                double change = cash - totalBill;

                showDialog(
                  context: context,
                  builder: (_) => Sukli(change: change),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
