import 'package:flutter/material.dart';
import 'package:cashier/class/productclass.dart';
import 'package:cashier/database/local_db.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({Key? key}) : super(key: key);

  @override
  _StockScreenState createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final LocalDatabase localDb = LocalDatabase();
  List<Productclass> products = [];
  List<Productclass> filteredProducts = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProducts();
    searchController.addListener(() {
      filterProducts();
    });
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
      filteredProducts = products
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> updateStock(Productclass product, int newStock) async {
    await localDb.updateProductStock(product.id, newStock);
    setState(() {
      product.stock = newStock;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Stock"),
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
                  borderSide: BorderSide(
                    color: Colors.blueAccent,
                    width: 2,
                  ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(product.name),
                      subtitle: Text(
                          "Price: ${product.price} | Stock: ${product.stock}"),
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

                                  // Show loading
                                  setInnerState(() => isSaving = true);

                                  // Update DB
                                  await updateStock(product, newStock);

                                  // Hide loading
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
    );
  }
}
