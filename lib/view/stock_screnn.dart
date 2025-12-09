import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cashier/class/productclass.dart';
import 'package:cashier/database/local_db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  _StockScreenState createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final LocalDatabase localDb = LocalDatabase();
  List<Productclass> products = [];
  List<Productclass> filteredProducts = [];
  TextEditingController searchController = TextEditingController();

  // Loading indicator for sync
  ValueNotifier<bool> isSyncing = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    loadProducts();
    searchController.addListener(filterProducts);

    // Auto-sync queued stock updates on start
    _autoSyncOnOnline();

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _syncWithLoading();
      }
    });
  }
Future<void> checkStockQueueTable() async {
  final db = await localDb.database;
  final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='stock_update_queue'");
  if (result.isNotEmpty) {
    print("✅ Table 'stock_update_queue' exists!");
  } else {
    print("❌ Table 'stock_update_queue' does NOT exist!");
  }
}
  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadProducts() async {
    final data = await localDb.getProducts();
    final loadedProducts = data
        .map((e) => Productclass(
              id: e['id'],
              name: e['name'],
              price: e['price'],
              stock: e['stock'],
              isPromo: e['is_promo'] == 1,
              otherQty: e['other_qty'] ?? 0,
            ))
        .toList();
    loadedProducts.sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      products = loadedProducts;
      filteredProducts = loadedProducts;
    });
  }

  void filterProducts() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredProducts =
          products.where((p) => p.name.toLowerCase().contains(query)).toList();
    });
  }

  // Update stock locally and queue for online sync
  Future<void> updateStock(Productclass product, int newStock) async {
    // Update local DB
    await localDb.updateProductStock(product.id, newStock);

    // Insert to local queue
    await localDb.insertStockUpdateQueue(product.id, newStock);

    if (await isOnline()) {
      try {
        // Try immediate online sync
        final response = await Supabase.instance.client
            .from('products')
            .update({'stock': newStock})
            .eq('id', product.id)
            .select();
        print("Supabase updated: $response");
        await localDb.markStockUpdateSynced(product.id);
      } catch (e) {
        print("Failed online update, queued: $e");
      }
    }

    setState(() {
      product.stock = newStock;
    });
  }

  // Sync queued updates with loading overlay
  Future<void> _syncWithLoading() async {
    if (!await isOnline()) return;

    isSyncing.value = true;
    final queuedUpdates = await localDb.getUnsyncedStockUpdates();

    for (var update in queuedUpdates) {
      try {
        final response = await Supabase.instance.client
            .from('products')
            .update({'stock': update['new_stock']})
            .eq('id', update['product_id'])
            .select();
        print("Synced queued update: $response");
        await localDb.markStockUpdateSynced(update['id']);
      } catch (e) {
        print("Failed to sync queued update: $e");
      }
    }

    isSyncing.value = false;
  }

  // Initial auto-sync on screen load if online
  Future<void> _autoSyncOnOnline() async {
    if (await isOnline()) {
      _syncWithLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text("Manage Stock"),
            actions: [
              IconButton(
                icon: Icon(Icons.sync),
                onPressed: () async {
                  await _syncWithLoading();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text("Sync completed")));
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: "Search products",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final controller =
                        TextEditingController(text: product.stock.toString());

                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(product.name),
                          subtitle: Text(
                              "Price: ₱${product.price} | Stock: ${product.stock}"),
                          trailing: SizedBox(
                            width: 110,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Stock',
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                StatefulBuilder(builder: (context, setInnerState) {
                                  bool isSaving = false;

                                  return IconButton(
                                    icon: isSaving
                                        ? SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(Icons.check, color: Colors.green),
                                    onPressed: () async {
                                      final newStock =
                                          int.tryParse(controller.text);
                                      if (newStock == null) return;

                                      // Confirm dialog
                                      bool confirmed = await showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text("Confirm Stock Update"),
                                              content: Text(
                                                  "Update stock of ${product.name} from ${product.stock} to $newStock?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, false),
                                                  child: Text("Cancel"),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, true),
                                                  child: Text("Confirm"),
                                                ),
                                              ],
                                            ),
                                          ) ??
                                          false;

                                      if (!confirmed) return;

                                      setInnerState(() => isSaving = true);

                                      await updateStock(product, newStock);

                                      setInnerState(() => isSaving = false);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "Stock updated for ${product.name}")),
                                      );
                                    },
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Loading overlay
        ValueListenableBuilder<bool>(
          valueListenable: isSyncing,
          builder: (context, loading, _) {
            if (!loading) return SizedBox.shrink();
            return Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        ),
      ],
    );
  }
}
