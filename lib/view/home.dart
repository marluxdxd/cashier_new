import 'package:cashier/database/local_db.dart';
import 'package:cashier/database/local_db_transactionpromo.dart';
import 'package:cashier/screens/debug_db_screen.dart';
import 'package:cashier/services/product_service.dart';
import 'package:cashier/services/transaction_service.dart';
import 'package:cashier/utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cashier/class/posrowclass.dart';
import 'package:cashier/widget/sukli.dart';
import 'package:cashier/widget/appdrawer.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../class/pos_row_manager.dart';

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
  bool isAutoNextRowOn = true; // default OFF
  bool isSyncingOnline = false;
  bool syncSuccess = false;
  StreamSubscription<InternetConnectionStatus>? _listener;
  StreamSubscription<ConnectivityResult>? _connectivityListener;

  // ----------------- Controllers & Services -----------------
  TextEditingController customerCashController = TextEditingController();
  final TransactionService transactionService = TransactionService();
  final ProductService productService = ProductService();

  bool isSyncing = false; // Loading indicator

  // ----------------- POS Manager -----------------
  late POSRowManager posManager;

  @override
  void initState() {
    super.initState();
    posManager = POSRowManager(context);

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
        await transactionService.syncOfflineTransactions();
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
      posManager.rows.clear();
    });

    try {
      await productService.syncOfflineProducts();
      final latestProducts = await productService.getAllProducts();

      if (!mounted) return;

      setState(() {
        posManager.rows = [POSRow()]; // start empty row
        syncSuccess = true;
      });
      print("Sync completed successfully!");
    } catch (e) {
      print("Error during product sync: $e");
    } finally {
      if (!mounted) return;
      setState(() => isSyncing = false);
    }
  }

  @override
  void dispose() {
    _listener?.cancel();
    _connectivityListener?.cancel();
    customerCashController.dispose();
    super.dispose();
  }

  void _updateUI() {
    setState(() {});
  }

  void _toggleAutoNextRow() {
    setState(() {
      isAutoNextRowOn = !isAutoNextRowOn;
    });
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
            Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(color: Colors.red),
            )
          else if (syncSuccess)
            Padding(
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
            // ---------------- Auto Next Row Button ----------------
            GestureDetector(
              onTap: _toggleAutoNextRow,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAutoNextRowOn
                      ? Colors.red
                      : Colors.black, // color depends on state
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isAutoNextRowOn ? "Auto Next Row: ON" : "Auto Next Row: OFF",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            // ---------------- POS Rows ----------------
            Expanded(
              child: ListView.builder(
                itemCount: posManager.rows.length,
                itemBuilder: (_, index) => posManager.buildRow(
                  posManager.rows[index],
                  index,
                  onUpdate: _updateUI,
                  isAutoNextRowOn: isAutoNextRowOn,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // Reset LOCAL
                final localDb = LocalDatabase();
                await localDb.resetLocalDatabase();

                // Reset ONLINE (Supabase)
                await Supabase.instance.client.rpc('reset_all_transactions');

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Database reset successful")),
                );
              },
              child: const Text("RESET ALL DATA"),
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

            // ---------------- TOTAL BILL ----------------
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
                    "₱${posManager.totalBill.toStringAsFixed(2)}",
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

            TextField(
              controller: customerCashController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Customer Cash",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) async {
                if (isSyncingOnline) return;
                final localDbPromo = LocalDbTransactionpromo();
                final double finalTotal = posManager.totalBill; // ✅ SAVE FIRST
                double cash = double.tryParse(customerCashController.text) ?? 0;

                if (!transactionService.isCashSufficient(
                  posManager.totalBill,
                  cash,
                )) {
                  print("Cash is not enough yet.");
                  return;
                }

                setState(() => isSyncingOnline = true);

                final bool online =
                    await InternetConnectionChecker().hasConnection;
                final localDb = LocalDatabase();
                double change = transactionService.calculateChange(
                  finalTotal,
                  cash,
                );
                String timestamp = getPhilippineTimestampFormatted();

                // ---------------- COMBINE SAME PRODUCTS ----------------
                final Map<int, POSRow> combinedItems = {};

                for (final row in posManager.rows) {
                  if (row.product == null) continue;

                  final product = row.product!;
                  final qty = row.isPromo ? row.otherQty : row.qty;

                  if (combinedItems.containsKey(product.id)) {
                    combinedItems[product.id]!.qty += qty;
                  } else {
                    combinedItems[product.id] = POSRow(
                      product: product,
                      qty: qty,
                      isPromo: row.isPromo,
                      otherQty: row.otherQty,
                    );
                  }
                }

                // ---------------- SHOW UI IMMEDIATELY ----------------
                final int savedPromoCount = posManager.promoCount;
                if (mounted) {
                  print("Promo count before reset: $savedPromoCount");
                  showDialog(
                    context: context,
                    builder: (_) => Sukli(change: change, timestamp: timestamp),
                  );
                  customerCashController.clear();
                  posManager.reset();
                  posManager.reset_promoCount();
                  _updateUI();
                }

                // ---------------- PROCESS TRANSACTION IN BACKGROUND ----------------
                unawaited(
                  Future(() async {
                    try {
                      final String clientUuid = const Uuid().v4();

                      final int localTransactionId = await localDb
                          .insertTransaction(
                            total: finalTotal,
                            cash: cash,
                            change: change,
                            createdAt: getPhilippineTimestampFormatted(),
                            isSynced: online ? 1 : 0,
                            clientUuid: clientUuid,
                          );

                      int? onlineTransactionId;

                      if (online) {
                        onlineTransactionId = await transactionService
                            .saveTransaction(
                              total: finalTotal,
                              cash: cash,
                              change: change,
                              clientUuid: clientUuid,
                            );

                        await localDb.updateTransactionSupabaseId(
                          localId: localTransactionId,
                          supabaseId: onlineTransactionId,
                        );
                      }
                      bool promoInserted = false; // 👈 add BEFORE map()
                      final futures = combinedItems.values.map((row) async {
                        final product = row.product!;
                        final qtySold = row.qty;
                        // final promoCount = posManager.promoCount;
                        int? oldStock = await localDb.getProductStock(
                          product.id,
                        );
                        int newStock = oldStock != null
                            ? oldStock - qtySold
                            : 0;
                        
                        await Future.wait([

                          // ✅ INSERT PROMO ONCE ONLY
    if (row.isPromo && savedPromoCount > 0 && !promoInserted)
      () async {
        promoInserted = true;

        print('🔥 INSERT PROMO | tx:$localTransactionId count:$savedPromoCount');

        await localDbPromo.insertTransactionPromo(
          transactionId: localTransactionId,
          productId: product.id,
          productName: product.name,
          promoCount: savedPromoCount, // ✅ CORRECT
          retailPrice: product.retailPrice,
          isSynced: online ? 1 : 0,
        );
      }(),
                     
                          localDb.insertTransactionItem(
                            transactionId: localTransactionId,
                            productId: product.id,
                            productName: product.name,
                            qty: qtySold,
                            retailPrice: product.retailPrice,
                            costPrice: product.costPrice,
                            isPromo: product.isPromo,
                            otherQty: product.otherQty,
                            productClientUuid: product.productClientUuid,
                          ),
                          if (oldStock != null)
                            localDb.updateProductStock(product.id, newStock),
                          if (oldStock != null)
                            localDb.updateProduct(
                              id: product.id,
                              stock: newStock,
                              retailPrice: product.retailPrice,
                              costPrice: product.costPrice,
                              isPromo: product.isPromo,
                              otherQty: product.otherQty,
                            ),
                          if (oldStock != null)
                            localDb.insertStockHistory(
                              transactionId: localTransactionId,
                              id: generateUniqueId(prefix: "H").hashCode.abs(),
                              productId: product.id,
                              productName: product.name,
                              oldStock: oldStock!,
                              qtyChanged: qtySold,
                              newStock: newStock,
                              type: 'SALE',
                              createdAt: timestamp,
                              synced: online ? 1 : 0,
                              productClientUuid: product.productClientUuid,
                            ),
                          localDb.insertStockUpdateQueue1(
                            productId: product.id,
                            qty: qtySold,
                            type: 'SALE',
                          ),
                          if (online && onlineTransactionId != null)
                            Future.wait([
                              productService.syncSingleProductOnline(
                                product.id,
                              ),
                              transactionService.saveTransactionItem(
                                transactionId: onlineTransactionId,
                                product: product,
                                qty: qtySold,
                                isPromo: product.isPromo,
                                otherQty: product.otherQty,
                              ),
                            ]),
                        ]);
                      }).toList();

                      await Future.wait(futures);

                      if (online) {
                        await productService.syncOnlineProducts();
                        await productService.syncOfflineStockHistory();
                        await productService.syncOfflineProducts();
                      }

                      print(
                        "✅ TRANSACTION SUCCESS (background sync completed)",
                      );
                    } catch (e) {
                      print("❌ Error saving transaction: $e");
                    } finally {
                      if (mounted) setState(() => isSyncingOnline = false);
                    }
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
