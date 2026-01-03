// import 'package:flutter/material.dart';
// import 'package:cashier/class/productclass.dart';
// import 'package:cashier/database/local_db.dart';
// import 'package:cashier/database/supabase.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';

// class AllProductsScreen extends StatefulWidget {
//   const AllProductsScreen({super.key});

//   @override
//   State<AllProductsScreen> createState() => _AllProductsScreenState();
// }

// class _AllProductsScreenState extends State<AllProductsScreen> {
//   final LocalDatabase localDb = LocalDatabase();
//   final supabase = SupabaseConfig.supabase;
//   List<Productclass> products = [];
//   List<Productclass> filteredProducts = [];
//   bool isLoading = true;
//   final TextEditingController searchController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     fetchProducts();
//   }

//   Future<bool> isOnline() async {
//     var connectivity = await Connectivity().checkConnectivity();
//     return connectivity != ConnectivityResult.none;
//   }

//   Future<void> fetchProducts() async {
//     setState(() => isLoading = true);

//     bool online = await isOnline();

//     if (online) {
//       // Fetch from Supabase
//       final data = await supabase.from('products').select();
//       products = (data as List<dynamic>)
//           .map((e) => Productclass.fromMap(e as Map<String, dynamic>))
//           .toList();

//       // Optional: update local DB
//       for (var p in products) {
//         await localDb.insertProduct(
//           id: p.id,
//           name: p.name,
//           price: p.price,
//           retailPrice: p.retailPrice,
//           costPrice: p.costPrice,
//           stock: p.stock,
//           isPromo: p.isPromo,
//           otherQty: p.otherQty,
//         );
//       }
//     } else {
//       // Fetch from local DB
//       final localData = await localDb.getProducts();
//       products = localData
//           .map((e) => Productclass(
//                 id: e['id'],
//                 name: e['name'],
//                 price: e['price'],
//                 retailPrice: e['retail_price'],
//                 costPrice: e['cost_price'],
//                 stock: e['stock'],
//                 isPromo: e['is_promo'] == 1,
//                 productClientUuid: e['client_uuid'] as String,
//                 otherQty: e['other_qty'] ?? 0,
//               ))
//           .toList();
//     }

//     setState(() {
//       filteredProducts = products;
//       isLoading = false;
//     });
//   }

//   void filterSearch(String query) {
//     if (query.isEmpty) {
//       setState(() => filteredProducts = products);
//     } else {
//       setState(() {
//         filteredProducts = products
//             .where((p) =>
//                 p.name.toLowerCase().contains(query.toLowerCase()))
//             .toList();
//       });
//     }
//   }

//   Future<void> updateStock(Productclass product) async {
//     TextEditingController stockController =
//         TextEditingController(text: product.stock.toString());

//     await showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text("Update Stock: ${product.name}"),
//         content: TextField(
//           controller: stockController,
//           keyboardType: TextInputType.number,
//           decoration: const InputDecoration(labelText: "New stock"),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("Cancel"),
//           ),
//           TextButton(
//             onPressed: () async {
//               int newStock = int.tryParse(stockController.text) ?? product.stock;

//               // Update local DB
//               await localDb.updateProductStock(product.id, newStock);

//               // Update Supabase if online
//               if (await isOnline()) {
//                 await supabase
//                     .from('products')
//                     .update({'stock': newStock})
//                     .eq('id', product.id);
//               }

//               setState(() {
//                 product.stock = newStock;
//               });

//               Navigator.pop(context);
//             },
//             child: const Text("Save"),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("All Products"),
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 Padding(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   child: TextField(
//                     controller: searchController,
//                     decoration: const InputDecoration(
//                       labelText: "Search product",
//                       prefixIcon: Icon(Icons.search),
//                       border: OutlineInputBorder(),
//                     ),
//                     onChanged: filterSearch,
//                   ),
//                 ),
//                 Expanded(
//                   child: ListView.builder(
//                     itemCount: filteredProducts.length,
//                     itemBuilder: (_, index) {
//                       final product = filteredProducts[index];
//                       return ListTile(
//                         title: Text(product.name),
//                         subtitle: Text(
//                             "Price: ${product.retailPrice} | Stock: ${product.stock}"),
//                         trailing: product.isPromo
//                             ? const Icon(Icons.local_offer, color: Colors.red)
//                             : null,
//                         onTap: () => updateStock(product),
//                       );
//                     },
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }
// }
