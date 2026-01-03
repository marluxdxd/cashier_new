import 'dart:io';
import 'package:cashier/database/local_db.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Tab2Screen extends StatefulWidget {
  const Tab2Screen({super.key});

  @override
  State<Tab2Screen> createState() => _Tab2ScreenState();
}

class _Tab2ScreenState extends State<Tab2Screen> {
  final LocalDatabase localDb = LocalDatabase();

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];

  bool isLoading = true;
  bool isSyncing = false;

  String selectedFilter = 'all';
  final TextEditingController searchController = TextEditingController();

  static const int lowStockThreshold = 5;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _listenConnectivity();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ================= LOAD PRODUCTS =================
  Future<void> _loadProducts() async {
    setState(() => isLoading = true);
    try {
      final db = await localDb.database;
      final result = await db.rawQuery('''
        SELECT
          id,
          name,
          stock,
          cost_price,
          retail_price,
          is_synced,
          (retail_price - cost_price) AS profit
        FROM products
        ORDER BY name ASC
      ''');

      products = result;
      _applyFilter();
    } catch (e) {
      debugPrint('Load stock error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ================= FILTER =================
  void _applyFilter() {
    List<Map<String, dynamic>> list = [...products];

    if (selectedFilter == 'low') {
      list = list.where((p) => (p['stock'] as int) <= lowStockThreshold).toList();
    } else if (selectedFilter == 'out') {
      list = list.where((p) => (p['stock'] as int) == 0).toList();
    }

    final q = searchController.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) => (p['name'] as String).toLowerCase().contains(q)).toList();
    }

    setState(() => filteredProducts = list);
  }

  // ================= CONNECTIVITY =================
  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _syncStock();
      }
    });
  }

  Future<bool> _isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }

  // ================= SYNC =================
  Future<void> _syncStock() async {
    if (!await _isOnline()) return;

    setState(() => isSyncing = true);

    try {
      final queue = await localDb.getUnsyncedStockUpdates();

      for (final q in queue) {
        final productId = q['product_id'];
        final queueId = q['id'];

        final finalStock = await localDb.getProductStock(productId);

        await Supabase.instance.client
            .from('products')
            .update({'stock': finalStock})
            .eq('id', productId);

        await localDb.markStockUpdateSynced(queueId);
      }

      await _loadProducts();
    } catch (e) {
      debugPrint('Sync error: $e');
    } finally {
      setState(() => isSyncing = false);
    }
  }

  // ================= STOCK HISTORY =================
  Future<void> _showStockHistory(int productId, String name) async {
    final db = await localDb.database;
    final history = await db.query(
      'product_stock_history',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Stock History – $name'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Text('No stock history')
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (_, i) {
                    final h = history[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${h['change_type']} (${h['qty_changed']})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Old: ${h['old_stock']} → New: ${h['new_stock']}\n${h['created_at']}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Row(
              children: [
                // PopupMenuButton<String>(
                //   icon: const Icon(Icons.filter_list),
                //   onSelected: (v) {
                //     selectedFilter = v;
                //     _applyFilter();
                //   },
                //   itemBuilder: (_) => const [
                //     PopupMenuItem(value: 'all', child: Text('All Products')),
                //     PopupMenuItem(value: 'low', child: Text('Low Stock')),
                //     PopupMenuItem(value: 'out', child: Text('Out of Stock')),
                //   ],
                // ),
                // IconButton(
                //   icon: const Icon(Icons.sync),
                //   onPressed: _syncStock,
                // ),
              ],
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search product',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (_) => _applyFilter(),
                          ),
                        ),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: filteredProducts.isEmpty
                              ? const Center(child: Text('No products found'))
                              : ListView.builder(
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (_, i) =>
                                      _tableRow(filteredProducts[i]),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        if (isSyncing)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // ================= TABLE =================
  Widget _tableHeader() {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Product', style: _header)),
          Expanded(
              flex: 1,
              child: Text('Stock', textAlign: TextAlign.right, style: _header)),
          Expanded(
              flex: 2,
              child: Text('Cost', textAlign: TextAlign.right, style: _header)),
          Expanded(
              flex: 2,
              child: Text('Retail', textAlign: TextAlign.right, style: _header)),
          Expanded(
              flex: 2,
              child: Text('Profit', textAlign: TextAlign.right, style: _header)),
          SizedBox(width: 26),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> p) {
    final profit = (p['profit'] as num?) ?? 0;
    final stock = (p['stock'] as int?) ?? 0;
    final isSynced = p['is_synced'] == 1;

    return InkWell(
      onTap: () => _showStockHistory(p['id'], p['name']),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                p['name'],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: stock <= lowStockThreshold ? Colors.red : Colors.black,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text('$stock',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color:
                          stock <= lowStockThreshold ? Colors.red : Colors.black)),
            ),
            Expanded(
              flex: 2,
              child: Text('₱${(p['cost_price'] as num).toStringAsFixed(2)}',
                  textAlign: TextAlign.right),
            ),
            Expanded(
              flex: 2,
              child: Text('₱${(p['retail_price'] as num).toStringAsFixed(2)}',
                  textAlign: TextAlign.right),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '₱${profit.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: profit >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(
              isSynced ? Icons.cloud_done : Icons.cloud_off,
              size: 18,
              color: isSynced ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

// ================= STYLE =================
const TextStyle _header = TextStyle(fontWeight: FontWeight.bold);
