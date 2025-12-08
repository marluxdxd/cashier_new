import 'package:flutter/material.dart';
import 'package:cashier/services/product_service.dart';
import 'package:cashier/class/productclass.dart';

class Productbottomsheet extends StatefulWidget {
  const Productbottomsheet({super.key,});

  @override
  State<Productbottomsheet> createState() => _ProductbottomsheetState();
}

class _ProductbottomsheetState extends State<Productbottomsheet> {
  TextEditingController searchController = TextEditingController();
 final productService = ProductService();  // ← importante kaayo
  List<Productclass> products = []; // Full list from Supabase
  List<Productclass> matchedProducts = []; // Filtered list for UI
  String input = "";
  //-------fetch products supabase--------------------
  @override
  void initState() {
    super.initState();
    // fetchProductsFromSupabase();
    loadProducts();  // ← new method
  }

  void loadProducts() async {
  try {
    final fetchedProducts = await productService.getAllProducts();

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
          height: MediaQuery.of(context).size.height * 0.5,
          padding: EdgeInsets.all(12),
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
            return ListTile(
              title: Text(product.name),
              subtitle: Text(
                'Price: ₱${product.price} • Stock: ${product.stock}',
              ),
              onTap: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context, product);
                print("You selected: ${product.name}");
              },
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
