import 'package:flutter/material.dart';
import 'package:cashier/services/product_service.dart';
import 'package:cashier/class/productclass.dart';

class Productbottomsheet extends StatefulWidget {
  const Productbottomsheet({super.key});

  @override
  State<Productbottomsheet> createState() => _ProductbottomsheetState();
}

class _ProductbottomsheetState extends State<Productbottomsheet> {
  ValueNotifier<bool> isSelected = ValueNotifier(false);
  TextEditingController searchController = TextEditingController();
  final productService = ProductService(); // ← importante kaayo
  List<Productclass> products = []; // Full list from Supabase
  List<Productclass> matchedProducts = []; // Filtered list for UI
  String input = "";
  //-------fetch products supabase--------------------
  @override
  void initState() {
    super.initState();
    isSelected.dispose();
    // fetchProductsFromSupabase();
    loadProducts(); // ← new metho
    productService.listenToConnectivity(() async {
      loadProducts();
    });
  }

  @override
  void dispose() {
    productService.disposeConnectivity();
    searchController.dispose();
    super.dispose();
  }

  void loadProducts() async {
    try {
      final fetchedProducts = await productService.getAllProducts();
      if (!mounted) return;

      setState(() {
        products = fetchedProducts;
        matchedProducts = fetchedProducts;
      });

      print("Loaded products: ${products.length}");
    } catch (e) {
      print("Error loading products: $e");
    }
  }

  void fetchProductsFromSupabase() async {
    try {
      final fetchedProducts = await Productclass.fetchProducts();
      setState(() {
        products = fetchedProducts;
        matchedProducts = fetchedProducts; // initially show all
      });
    } catch (e) {
      print("Error fetching products: $e");
    }
  }

  //--------------- Filter products by search-----------------------------------
  void filterProducts(String value) {
    setState(() {
      input = value;
      matchedProducts = products.where((product) {
        return product.name.toLowerCase().contains(value.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.3,
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 50,
                height: 5,
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Search bar
              TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search product...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: filterProducts,
              ),

              SizedBox(height: 10),

              // Product list
              Expanded(
                child: matchedProducts.isEmpty
                    ? Center(child: Text("No products found"))
                    : ListView.builder(
                        itemCount: matchedProducts.length,
                        itemBuilder: (_, index) {
                          final product = matchedProducts[index];

                          return Container(
                            child: ListTile(
                              title: Row(
                                children: [
                                  Text(product.name),
                                  if (product.isPromo) ...[
                                    SizedBox(width: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "PROMO ${product.otherQty}x${product.retailPrice}",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (product.stock == 0) ...[
                                    SizedBox(width: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "NO STOCK",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                'Price: ₱${product.retailPrice} • Stock: ${product.stock}',
                              ),
                              onTap: product.stock == 0
                                  ? null // disable tap if out of stock
                                  : () {
                                      FocusScope.of(context).unfocus();
                                      Navigator.pop(context, product);
                                      print("You selected: ${product.name}");
                                    },
                            ),
                          );
                        },
                      ),
                      
              ),
              
            ],
          ),
        ),
        
      ),
    );
  }
}
