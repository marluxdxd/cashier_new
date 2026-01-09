// import 'package:cashier/database/local_db.dart';
// import 'package:cashier/view/appproductedit.dart';
// import 'package:cashier/widget/addproduct.dart';
// import 'package:flutter/material.dart';

// class ProductsPage extends StatefulWidget {
//   const ProductsPage({super.key});

//   @override
//   State<ProductsPage> createState() => _ProductsPageState();
// }

// class _ProductsPageState extends State<ProductsPage> {
//   final LocalDatabase db = LocalDatabase();
//   List<Map<String, dynamic>> products = [];
//   List<Map<String, dynamic>> filteredProducts = [];
//   bool isLoading = false;
//   String searchQuery = '';

//   @override
//   void initState() {
//     super.initState();
//     loadProducts();
//   }

//   /// ---------------- LOAD PRODUCTS ----------------
//   Future<void> loadProducts() async {
//     setState(() => isLoading = true);
//     try {
//       products = await db.getProducts();
//       applySearch(searchQuery);
//     } catch (e) {
//       // optional: handle DB error
//       debugPrint("Error loading products: $e");
//     }
//     setState(() => isLoading = false);
//   }

//   /// ---------------- SEARCH FILTER ----------------
//   void applySearch(String query) {
//     searchQuery = query;
//     if (query.isEmpty) {
//       filteredProducts = [...products];
//     } else {
//       filteredProducts = products
//           .where((p) =>
//               (p['name'] as String).toLowerCase().contains(query.toLowerCase()))
//           .toList();
//     }
//     setState(() {}); // refresh UI
//   }

//   /// ---------------- EDIT PRODUCT ----------------
//   void editProduct(Map<String, dynamic> product) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => AddProductPageEdit(product: product),
//       ),
//     ).then((_) => loadProducts()); // refresh after edit
//   }

//   /// ---------------- DELETE PRODUCT ----------------
//   void deleteProduct(int id, String name) async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Confirm Delete'),
//         content: Text('Delete product "$name"?'),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.pop(context, false),
//               child: const Text('Cancel')),
//           TextButton(
//               onPressed: () => Navigator.pop(context, true),
//               child: const Text('Delete')),
//         ],
//       ),
//     );

//     if (confirm == true) {
//       try {
//         await db.deleteProduct(id);

//         // Reset local SQLite sequence after deletion
//         await db.resetLocalProductIdSequence();

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Deleted product "$name"')),
//         );
//         await loadProducts(); // refresh list
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error deleting product: $e')),
//         );
//       }
//     }
//   }

//   /// ---------------- BUILD UI ----------------
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Products')),
//       body: Column(
//         children: [
//           // ---------------- SEARCH FIELD ----------------
//           Padding(
//             padding: const EdgeInsets.all(10),
//             child: TextField(
//               decoration: const InputDecoration(
//                 labelText: 'Search product',
//                 prefixIcon: Icon(Icons.search),
//                 border: OutlineInputBorder(),
//               ),
//               onChanged: applySearch,
//             ),
//           ),

//           // ---------------- PRODUCT LIST ----------------
//           Expanded(
//             child: isLoading
//                 ? const Center(child: CircularProgressIndicator())
//                 : filteredProducts.isEmpty
//                     ? const Center(child: Text('No products found'))
//                     : ListView.builder(
//                         itemCount: filteredProducts.length,
//                         itemBuilder: (_, index) {
//                           final p = filteredProducts[index];
//                           return ListTile(
//                             title: Text(p['name']),
//                             subtitle: Text(
//                                 'Stock: ${p['stock']}, Retail: ₱${p['retail_price']}, Promo: ${p['is_promo'] == 1 ? "Yes" : "No"}'),
//                             trailing: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 IconButton(
//                                   icon: const Icon(Icons.edit),
//                                   onPressed: () => editProduct(p),
//                                 ),
//                                 IconButton(
//                                   icon: const Icon(Icons.delete),
//                                   onPressed: () =>
//                                       deleteProduct(p['id'], p['name']),
//                                 ),
//                               ],
//                             ),
//                           );
//                         },
//                       ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(builder: (_) => const AddProductPage()),
//           ).then((_) => loadProducts()); // refresh after adding
//         },
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
