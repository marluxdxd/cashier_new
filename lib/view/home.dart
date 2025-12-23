import 'package:cashier/database/local_db.dart';
import 'package:cashier/screens/debug_db_screen.dart';
import 'package:cashier/services/product_service.dart';
import 'package:cashier/services/transaction_service.dart';
import 'package:cashier/utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cashier/class/productclass.dart';
import 'package:cashier/class/posrowclass.dart';
import 'package:cashier/widget/productbottomsheet.dart';
import 'package:cashier/widget/qtybottomsheet.dart';
import 'package:cashier/widget/sukli.dart';
import 'package:cashier/widget/appdrawer.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'dart:async';

// ------------------ Helper Functions ------------------
String generateUniqueId({String prefix = "S"}) {
  return "$prefix${DateTime.now().millisecondsSinceEpoch}";
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isSyncingOnline = false;
  bool syncSuccess = false;
  StreamSubscription<InternetConnectionStatus>? _listener;
  StreamSubscription<ConnectivityResult>? _connectivityListener;

  //----------------------Controller---------------------------
  List<POSRow> rows = [POSRow()]; // Start with one empty row
  TextEditingController customerCashController = TextEditingController();
  final TransactionService transactionService = TransactionService();
  List<Productclass> matchedProducts = [];
  final productService = ProductService(); // ← importante kaayo

  bool isSyncing = false; // Loading indicator

  @override
  void initState() {
    super.initState();
    // 🔹 Automatic sync on startup
    _syncOnStartup();

    // Sync offline products on init → this will also load all products
    syncProducts();

    // Listen for connection changes
    _listener = InternetConnectionChecker().onStatusChange.listen((
      status,
    ) async {
      if (status == InternetConnectionStatus.connected) {
        await productService.syncOfflineProducts();
        await productService.syncOnlineProducts();
        await transactionService.syncOfflineTransactions(); // 👈 IMPORTANT
        await syncProducts();
        
      }
    });
    _connectivityListener = Connectivity().onConnectivityChanged.listen((
      status,
    ) {
      if (status != ConnectivityResult.none) syncProducts();
    });
  }

  Future<void> _syncOnStartup() async {
    final online = await ProductService().isOnline1();
    if (online) {
      await ProductService().syncOnlineProducts();
    }
  }

  Future<void> syncProducts() async {
    if (!mounted) return;

    setState(() {
      isSyncing = true;
      syncSuccess = false;
      matchedProducts.clear();
    });

    try {
      await productService.syncOfflineProducts();
      final latestProducts = await productService.getAllProducts();

      if (!mounted) return; // ✅ check again

      setState(() {
        matchedProducts = latestProducts;
        syncSuccess = true;
      });
      print("Sync completed successfully!");
    } catch (e) {
      print("Error during product sync: $e");
    } finally {
      if (!mounted) return; // ✅ check again
      setState(() => isSyncing = false);
    }
  }

  @override
  void dispose() {
    _listener?.cancel();
    _connectivityListener?.cancel();
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
          total += row.product!.price;
        } else {
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
                    row.isPromo = selectedProduct.isPromo;
                    row.otherQty = selectedProduct.isPromo
                        ? selectedProduct.otherQty
                        : 0;

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
                  ? null
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
                      ? row.otherQty.toString()
                      : (row.qty == 0 ? "Qty" : row.qty.toString()),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          SizedBox(width: 8),

          // Row total
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
          if (isSyncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(color: Colors.red),
            )
          else if (syncSuccess)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.check_circle, color: Colors.green, size: 30),
            ),
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
            IconButton(
              icon: const Icon(Icons.storage),
              tooltip: "Open DB Debug",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DebugDbScreen()),
                );
              },
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
  if (isSyncingOnline) return;

  double cash = double.tryParse(customerCashController.text) ?? 0;

  if (!transactionService.isCashSufficient(totalBill, cash)) {
    print("Cash is not enough yet.");
    return;
  }

  setState(() {
    isSyncingOnline = true;
  });

  final bool online = await InternetConnectionChecker().hasConnection;
  final localDb = LocalDatabase();
  double change = transactionService.calculateChange(totalBill, cash);
  String timestamp = getPhilippineTimestampFormatted();

  try {
    // ================= 1️⃣ INSERT TRANSACTION LOCALLY =================
    final int localTransactionId = generateUniqueId(prefix: "T").hashCode.abs();
    await localDb.insertTransaction(
      id: localTransactionId,
      total: totalBill,
      cash: cash,
      change: change,
      createdAt: timestamp,
      isSynced: online ? 1 : 0,
    );

    // ================= 2️⃣ INSERT ONLINE TRANSACTION IF CONNECTED =================
    int onlineTransactionId = localTransactionId;
    if (online) {
      onlineTransactionId = await transactionService.saveTransaction(
        total: totalBill,
        cash: cash,
        change: change,
      );
    }

    // ================= 3️⃣ PROCESS EACH ITEM =================
    for (var row in rows) {
      if (row.product == null) continue;

      final product = row.product!;
      final qtySold = row.isPromo ? row.otherQty : row.qty;

      // Insert transaction item locally
      await localDb.insertTransactionItem(
        id: generateUniqueId(prefix: "TI").hashCode.abs(),
        transactionId: localTransactionId, // use local transaction ID
        productId: product.id,
        productName: product.name,
        qty: qtySold,
        price: product.price,
        isPromo: product.isPromo,
        otherQty: product.otherQty,
      );

      // Update local stock
      int? oldStock = await localDb.getProductStock(product.id);
      if (oldStock == null) continue;

      int newStock = oldStock - qtySold;
      await localDb.updateProductStock(product.id, newStock);
      await localDb.updateProduct(
        id: product.id,
        stock: newStock,
        price: product.price,
        isPromo: product.isPromo,
        otherQty: product.otherQty,
      );

      // Insert stock history
      await localDb.insertStockHistory(
        id: generateUniqueId(prefix: "H").hashCode.abs(),
        productId: product.id,
        oldStock: oldStock,
        qtyChanged: qtySold,
        newStock: newStock,
        type: 'SALE',
        createdAt: timestamp,
        synced: online ? 1 : 0,
      );

      await localDb.insertStockUpdateQueue1(
        productId: product.id,
        qty: qtySold,
        type: 'SALE',
      );

      // Sync online if connected
      if (online) {
        await productService.syncSingleProductOnline(product.id);

        await transactionService.saveTransactionItem(
          transactionId: onlineTransactionId, // use online transaction ID
          product: product,
          qty: qtySold,
          isPromo: product.isPromo,
          otherQty: product.otherQty,
        );
      }
    }

    // ================= 4️⃣ FINAL ONLINE SYNC =================
    if (online) {
      await productService.syncOnlineProducts();
      await productService.syncOfflineStockHistory();
      await productService.syncOfflineProducts();
    }

    // ================= 5️⃣ UPDATE UI =================
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => Sukli(change: change, timestamp: timestamp),
      );

      customerCashController.clear();
      setState(() {
        rows = [POSRow()]; // reset POS rows
      });
    }

    print("✅ Transaction + Sync SUCCESS");
  } catch (e) {
    print("❌ Error saving transaction: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save transaction.")),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        isSyncingOnline = false;
      });
    }
  }
}

            ),
          ],
        ),
      ),
    );
  }
}
