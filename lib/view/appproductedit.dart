// import 'package:cashier/database/local_db.dart';
// import 'package:cashier/services/product_service.dart';
// import 'package:cashier/services/transaction_service.dart';
// import 'package:cashier/services/transactionitem_service.dart';
// import 'package:cashier/services/transaction_promo_service.dart';
// import 'package:cashier/services/stock_history_sync.dart';
// import 'package:cashier/services/connectivity_service.dart';
// import 'package:flutter/material.dart';

// class AddProductPageEdit extends StatefulWidget {
//   final Map<String, dynamic> product;

//   const AddProductPageEdit({super.key, required this.product});

//   @override
//   State<AddProductPageEdit> createState() => _AddProductPageEditState();
// }

// class _AddProductPageEditState extends State<AddProductPageEdit> {
//   final LocalDatabase db = LocalDatabase();
//   final ProductService productService = ProductService();
//   final TransactionService transactionService = TransactionService();
//   final TransactionItemService transactionItemService = TransactionItemService();
//   final StockHistorySyncService stockHistorySyncService = StockHistorySyncService();
//   final TransactionPromoService transactionPromoService = TransactionPromoService();

//   late ConnectivityService connectivityService;

//   late TextEditingController nameController;
//   late TextEditingController costPriceController;
//   late TextEditingController retailPriceController;
//   late TextEditingController byPiecesController;
//   late TextEditingController promoQtyController;

//   bool isPromo = false;
//   int otherQty = 0;
//   double pricePerPiece = 0;
//   double priceInterest = 0;
//   bool isLoading = false;

//   @override
//   void initState() {
//     super.initState();

//     // Initialize controllers
//     nameController = TextEditingController(text: widget.product['name']);
//     costPriceController = TextEditingController(
//         text: (widget.product['cost_price'] ?? 0).toString());
//     retailPriceController = TextEditingController(
//         text: (widget.product['retail_price'] ?? 0).toString());
//     byPiecesController =
//         TextEditingController(text: (widget.product['by_pieces'] ?? 1).toString());
//     promoQtyController = TextEditingController(
//         text: (widget.product['other_qty'] ?? 0).toString());

//     isPromo = (widget.product['is_promo'] ?? 0) == 1;
//     otherQty = widget.product['other_qty'] ?? 0;

//     computeInterest();

//     // Initialize ConnectivityService for automatic sync
//     connectivityService = ConnectivityService(
//       productService: productService,
//       transactionService: transactionService,
//       transactionItemService: transactionItemService,
//       stockHistorySyncService: stockHistorySyncService,
//       transactionPromoService: transactionPromoService,
//     );
//   }

//   void computeInterest() {
//     final costPrice = double.tryParse(costPriceController.text) ?? 0;
//     final retailPrice = double.tryParse(retailPriceController.text) ?? 0;
//     final pieces = int.tryParse(byPiecesController.text) ?? 1;
//     final qtyPromo = int.tryParse(promoQtyController.text) ?? 1;

//     if (pieces == 0) {
//       setState(() {
//         pricePerPiece = 0;
//         priceInterest = 0;
//       });
//       return;
//     }

//     if (isPromo && qtyPromo > 0) {
//       final ppp = costPrice / pieces;
//       final promoSets = pieces ~/ qtyPromo;
//       final totalRetail = promoSets * retailPrice;
//       setState(() {
//         pricePerPiece = ppp;
//         priceInterest = totalRetail - costPrice;
//       });
//     } else {
//       final ppp = costPrice / pieces;
//       setState(() {
//         pricePerPiece = ppp;
//         priceInterest = retailPrice - ppp;
//       });
//     }
//   }

//   void computePricePerPiece() {
//     final costPrice = double.tryParse(costPriceController.text) ?? 0;
//     final pieces = int.tryParse(byPiecesController.text) ?? 1;

//     if (pieces == 0) {
//       setState(() => pricePerPiece = 0);
//     } else {
//       setState(() => pricePerPiece = costPrice / pieces);
//     }

//     computeInterest();
//   }

//   void computePromo() {
//     if (isPromo) computeInterest();
//   }

//   /// ---------------- SAVE PRODUCT ---------------- ///
//   void saveProduct() async {
//     final name = nameController.text.trim();
//     final costPrice = double.tryParse(costPriceController.text) ?? 0;
//     final retailPrice = double.tryParse(retailPriceController.text) ?? 0;
//     otherQty = int.tryParse(promoQtyController.text) ?? 0;

//     if (name.isEmpty) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text("Enter product name")));
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       // 1️⃣ Update locally first
//       await db.updateProduct(
//         id: widget.product['id'],
//         stock: widget.product['stock'] ?? 0,
//         costPrice: costPrice,
//         retailPrice: retailPrice,
//         isPromo: isPromo,
//         otherQty: otherQty,
//       );

//       // 2️⃣ Attempt online sync immediately
//       final online = await productService.isOnline1();
//       if (online) {
//         await productService.syncSingleProductOnline(widget.product['id']);
//         await transactionService.syncOfflineTransactions();
//         await transactionPromoService.syncOfflinePromos();
//         await stockHistorySyncService.syncStockHistory();
//         // 3️⃣ Reset product ID sequence after sync
//       await productService.resetProductIdSequence();
//       }

//       setState(() => isLoading = false);

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Product updated successfully!")),
//       );

//       Navigator.pop(context);
//     } catch (e) {
//       setState(() => isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error updating product: $e")),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     nameController.dispose();
//     costPriceController.dispose();
//     retailPriceController.dispose();
//     byPiecesController.dispose();
//     promoQtyController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Edit Product")),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           children: [
//             CheckboxListTile(
//               title: const Text("Promo"),
//               value: isPromo,
//               onChanged: (val) {
//                 setState(() => isPromo = val ?? false);
//                 computeInterest();
//               },
//             ),
//             if (isPromo)
//               TextField(
//                 controller: promoQtyController,
//                 keyboardType: TextInputType.number,
//                 decoration: const InputDecoration(labelText: "Qty for Promo"),
//                 onChanged: (_) => computePromo(),
//               ),
//             TextField(
//               controller: nameController,
//               decoration: const InputDecoration(labelText: "Product Name"),
//             ),
//             TextField(
//               controller: costPriceController,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(labelText: "Cost Price"),
//               onChanged: (_) => computePricePerPiece(),
//             ),
//             TextField(
//               controller: byPiecesController,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(labelText: "By Pieces"),
//               onChanged: (_) => computePricePerPiece(),
//             ),
//             const SizedBox(height: 10),
//             if (!isPromo)
//               Row(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(6),
//                     decoration: BoxDecoration(
//                       border: Border.all(color: Colors.grey),
//                       borderRadius: BorderRadius.circular(4),
//                       color: Colors.grey[200],
//                     ),
//                     child: Text(
//                         'Price per piece: ₱${pricePerPiece.toStringAsFixed(2)}'),
//                   ),
//                 ],
//               ),
//             TextField(
//               controller: retailPriceController,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(labelText: "Retail Price"),
//               onChanged: (_) => computeInterest(),
//             ),
//             const SizedBox(height: 10),
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(6),
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey),
//                     borderRadius: BorderRadius.circular(4),
//                     color: Colors.grey[200],
//                   ),
//                   child: Text('Interest ₱${priceInterest.toStringAsFixed(2)}'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: isLoading ? null : saveProduct,
//               child: isLoading
//                   ? const CircularProgressIndicator(color: Colors.white)
//                   : const Text("Update Product"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
