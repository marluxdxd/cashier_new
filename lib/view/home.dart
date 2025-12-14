import 'package:cashier/database/local_db.dart';
import 'package:cashier/services/product_service.dart';
import 'package:cashier/services/transaction_service.dart';
import 'package:flutter/material.dart';
import 'package:cashier/class/productclass.dart';
import 'package:cashier/class/posrowclass.dart';
import 'package:cashier/widget/productbottomsheet.dart';
import 'package:cashier/widget/qtybottomsheet.dart';
import 'package:cashier/widget/sukli.dart';
import 'package:cashier/widget/appdrawer.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'dart:async';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
  
}

class _HomeState extends State<Home> {
  StreamSubscription<InternetConnectionStatus>? _listener;

  
  //----------------------Controller---------------------------
  List<POSRow> rows = [POSRow()]; // Start with one empty row
  TextEditingController customerCashController = TextEditingController();
  final TransactionService transactionService = TransactionService();
  List<Productclass> matchedProducts = [];
  final productService = ProductService(); // ← importante kaayo

@override
void initState() {
  super.initState();
  loadProducts(); // existing code

  // Internet status listener
_listener = InternetConnectionChecker().onStatusChange.listen((status) async {
  if (status == InternetConnectionStatus.connected) {
    print("Device online → syncing queued stock...");
    final localDb = LocalDatabase();
    await localDb.syncQueuedStockWithServer(transactionService);
  }
});
}

  @override
void dispose() {
  _listener?.cancel();
  customerCashController.dispose(); // existing controller dispose
  super.dispose();
}

  void loadProducts() async {
    final products = await productService.getAllProducts();
    setState(() {
      matchedProducts = products;
    });
  }

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
      if (row.product != null) {
        if (row.isPromo) {
          // Promo product → total = product price only
          total += row.product!.price;
        } else {
          // Normal product → total = price * qty
          total += row.product!.price * row.qty;
        }
      }
    }
    return total;
  }

  //-----------------Build Each POS Row---------------------------
  Widget buildRow(POSRow row, int index) {
    double displayPrice = 0;
    if (row.product != null) {
      displayPrice = row.isPromo
          ? row.product!.price
          : row.product!.price * row.qty;
    } else {
      displayPrice = 0;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Product
          Expanded(
            flex: 6,
            child: InkWell(
              onTap: () async {
                final selectedProduct =
                    await showModalBottomSheet<Productclass>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => Productbottomsheet(),
                    );
                if (selectedProduct != null) {
                  setState(() {
                    row.product = selectedProduct;

                    // Kung promo product, set isPromo true and fix quantity
                    if (selectedProduct.isPromo) {
                      // depende kung Productclass naay isPromo
                      row.isPromo = true;
                      row.otherQty =
                          selectedProduct.otherQty; // fix ang quantity
                    } else {
                      row.isPromo = false;
                    }

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
              onTap: row.isPromo
                  ? null // fixed quantity
                  : () async {
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
                  color: row.isPromo ? Colors.grey[200] : Colors.white,
                ),
                child: Text(
                  row.isPromo
                      ? row.otherQty
                            .toString() // fixed quantity, dili ma-edit
                      : (row.qty == 0 ? "Qty" : row.qty.toString()),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          SizedBox(width: 8),

          // Row total
          // Row total with promo logic
          Text(
            "₱${displayPrice.toStringAsFixed(2)}",
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
            // PRODUCT+QTY ROWS
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
              onSubmitted: (_) async {
                double cash = double.tryParse(customerCashController.text) ?? 0;

                if (!transactionService.isCashSufficient(totalBill, cash)) {
                  print("Cash is not enough yet.");
                  return;
                }

                final bool online =
                    await InternetConnectionChecker().hasConnection;
                final localDb = LocalDatabase();

                double change = transactionService.calculateChange(
                  totalBill,
                  cash,
                );
                String timestamp = transactionService.getCurrentTimestamp();

                if (!online) {
                  // ------------------------------------------
                  //  OFFLINE MODE: SAVE TO LOCAL SQLITE
                  // ------------------------------------------
                  print("OFFLINE MODE → Saving to Local DB");

                  // 1️⃣ insert transaction locally
                  int localTrxId = await localDb.insertTransaction(
                    id: DateTime.now()
                        .millisecondsSinceEpoch, // temporary local ID
                    total: totalBill,
                    cash: cash,
                    change: change,
                    createdAt: timestamp,
                  );

                  // 2️⃣ insert items locally
                  for (var row in rows) {
                    if (row.product != null) {
                      int qty = row.isPromo ? row.otherQty : row.qty;

//--------------------------------------------------------
//--------------------------------------------------------
//--------------------------------------------------------


                      
  // 🔥 GET ACTUAL STOCK FROM LOCAL DB
    int? currentStock =
        await localDb.getProductStock(row.product!.id);

    print(
      "PRODUCT: ${row.product!.name} | "
      "DB STOCK: $currentStock | "
      "QTY: $qty",
    );
  if (currentStock == null) {
      print("ERROR: Product not found in local DB");
      return;
    }
       // 🚨 PREVENT NEGATIVE STOCK
    if (currentStock < qty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Insufficient stock for ${row.product!.name}",
          ),
        ),
      );
      return;
    }

// minus stock locally
int newStock = currentStock - qty;
await localDb.updateProductStock(row.product!.id, newStock);

// queue stock change
await localDb.insertStockUpdateQueue1(
  productId: row.product!.id,
  qty: qty,
  type: 'SALE',
);

print(
  "QUEUED STOCK → "
  "${row.product!.name} | QTY: -$qty",
);
                      //MARLU TESTING//-------------------------------------------------------------
                        //MARLU TESTING//-------------------------------------------------------------
                          //MARLU TESTING//-------------------------------------------------------------
//                     int test = qty - 1;
           
//                       print(
//                         "PRODUCT: ${row.product!.name} | QTY: $qty | STOCK BEFORE: ${row.product!.stock}",
//                       );
//                       print("""
// PRODUCT ID: ${row.product!.id}
// NAME: ${row.product!.name}
// QTY: $qty $test
// PRICE: ${row.product!.price}
// IS PROMO: ${row.isPromo}
// """);
  //MARLU TESTING//-------------------------------------------------------------
    //MARLU TESTING//-------------------------------------------------------------
      //MARLU TESTING//-------------------------------------------------------------
                      await localDb.insertTransactionItem(
                        id: DateTime.now().millisecondsSinceEpoch,
                        transactionId: localTrxId,
                        productId: row.product!.id,
                        productName: row.product!.name,
                        qty: qty,
                        price: row.product!.price,
                        isPromo: row.isPromo,
                        otherQty: row.otherQty,
                      );
                    }
                  }

                  print("OFFLINE SAVE SUCCESS!");

                  showDialog(
                    context: context,
                    builder: (_) => Sukli(change: change, timestamp: timestamp),
                  );

                  customerCashController.clear();
                  setState(() {
                    rows = [POSRow()];
                  });

                  return; // Stop here because offline
                }

                // ------------------------------------------
                //  ONLINE MODE (REAL SUPABASE SAVE)
                // ------------------------------------------
                try {
                  int transactionId = await transactionService.saveTransaction(
                    total: totalBill,
                    cash: cash,
                    change: change,
                  );

                  print("ONLINE → Transaction saved! ID: $transactionId");

                  for (var row in rows) {
                    if (row.product != null) {
                      int qty = row.isPromo ? row.otherQty : row.qty;

                      await transactionService.saveTransactionItem(
                        transactionId: transactionId,
                        product: row.product!,
                        qty: qty,
                        isPromo: row.isPromo,
                        otherQty: row.otherQty,
                      );

                      await transactionService.updateStock(
                        productId: row.product!.id,
                        newStock: row.product!.stock - qty,
                      );
                    }
                  }

                  showDialog(
                    context: context,
                    builder: (_) => Sukli(change: change, timestamp: timestamp),
                  );

                  customerCashController.clear();
                  setState(() {
                    rows = [POSRow()];
                  });
                } catch (e) {
                  print("Error saving transaction: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to save transaction.")),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
