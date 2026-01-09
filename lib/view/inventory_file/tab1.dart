import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cashier/class/productclass.dart';
import 'package:cashier/database/local_db.dart';
import 'package:cashier/services/product_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen>
    with AutomaticKeepAliveClientMixin {
  final LocalDatabase localDb = LocalDatabase();
  final ProductService productService = ProductService();

  List<Productclass> products = [];
  List<Productclass> filteredProducts = [];
  final TextEditingController searchController = TextEditingController();
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  // Controllers for each product to avoid recreating them
  final Map<int, TextEditingController> _stockControllers = {};

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _setupConnectivityListener();
    _autoSyncOnOnline();
  }

  @override
  void dispose() {
    searchController.dispose();
    isSyncing.dispose();
    _stockControllers.values.forEach((c) => c.dispose());
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _syncWithLoading();
      }
    });
  }

  Future<void> _loadProducts() async {
    final fetchedProducts = await productService.getAllProducts();
    fetchedProducts.sort((a, b) => a.name.compareTo(b.name));

    // Initialize controllers
    for (var p in fetchedProducts) {
      _stockControllers[p.id] =
          TextEditingController(text: p.stock.toString());
    }

    if (!mounted) return;
    setState(() {
      products = fetchedProducts;
      filteredProducts = fetchedProducts;
    });
  }

  void _filterProducts(String query) {
    final filtered = products.where((p) {
      return p.name.toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (!mounted) return;
    setState(() {
      filteredProducts = filtered;
    });
  }

  Future<bool> _isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }

  Future<void> _updateStock(Productclass product, int newStock) async {
    final diff = newStock - product.stock;
    if (diff == 0) return;

    // Update local DB
    await localDb.updateProductStock(product.id, newStock);

    // Add to stock queue
    await localDb.insertStockUpdateQueue1(
      productId: product.id,
      qty: diff.abs(),
      type: diff > 0 ? 'ADD' : 'SUB',
    );

    if (!mounted) return;
    setState(() {
      product.stock = newStock;
      _stockControllers[product.id]?.text = newStock.toString();
    });
  }

  Future<void> _syncWithLoading() async {
    if (!await _isOnline()) return;

    isSyncing.value = true;

    try {
      final queue = await localDb.getUnsyncedStockUpdates();

      for (final item in queue) {
        try {
          final productId = item['product_id'];
          final queueId = item['id'];

          final finalStock = await localDb.getProductStock(productId);

          await Supabase.instance.client
              .from('products')
              .update({'stock': finalStock})
              .eq('id', productId);

          await localDb.markStockUpdateSynced(queueId);
        } catch (e) {
          debugPrint("Sync failed: $e");
        }
      }
    } finally {
      if (mounted) isSyncing.value = false;
    }
  }

  Future<void> _autoSyncOnOnline() async {
    if (await _isOnline()) {
      await _syncWithLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // for AutomaticKeepAliveClientMixin

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: "Search product",
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _filterProducts,
              ),
            ),
            Expanded(
              child: filteredProducts.isEmpty
                  ? const Center(child: Text("No products found"))
                  : ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (_, index) {
                        final product = filteredProducts[index];
                        final controller = _stockControllers[product.id]!;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: ListTile(
                            title: Text(product.name),
                            subtitle: Text("Stock: ${product.stock}"),
                            trailing: SizedBox(
                              width: 120,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: controller,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 6),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                    ),
                                    onPressed: () async {
                                      final newStock =
                                          int.tryParse(controller.text);
                                      if (newStock == null) return;

                                      await _updateStock(product, newStock);
                                      await _syncWithLoading();

                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content:
                                            Text("${product.name} updated"),
                                      ));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        // Loading overlay
        ValueListenableBuilder<bool>(
          valueListenable: isSyncing,
          builder: (_, loading, __) {
            if (!loading) return const SizedBox.shrink();
            return Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
