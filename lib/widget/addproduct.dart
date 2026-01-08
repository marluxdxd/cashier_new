import 'package:cashier/services/product_service.dart';
import 'package:flutter/material.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  double pricePerPiece = 0;
  double priceInterest = 0;

  final nameController = TextEditingController();
  final costPriceController = TextEditingController();
  final byPiecesController = TextEditingController();
  final retailPriceController = TextEditingController();
  final promoQtyController = TextEditingController();

  final productService = ProductService();

  bool isLoading = false;
  bool isPromo = false;
  int otherQty = 0;

  /// ------------------- CALCULATIONS ------------------- ///
  /// 

  void computePromoLogic() {
  final costPrice = double.tryParse(costPriceController.text) ?? 0;
  final pieces = int.tryParse(byPiecesController.text) ?? 0;
  final qtyPromo = int.tryParse(promoQtyController.text) ?? 0;
  final retailPrice = double.tryParse(retailPriceController.text) ?? 0;

  if (pieces == 0 || qtyPromo == 0) {
    setState(() {
      pricePerPiece = 0;
      priceInterest = 0;
    });
    return;
  }

  // price per piece
  final ppp = costPrice / pieces;

  // compute how many promo sets
  final promoSets = (pieces ~/ qtyPromo); // integer divide

  // compute total retail
  final totalRetail = promoSets * retailPrice;

  // compute interest
  final interest = totalRetail - costPrice;

  setState(() {
    pricePerPiece = ppp;
    priceInterest = interest;
  });
}

  void computePricePerPiece() {
    final costPrice = double.tryParse(costPriceController.text) ?? 0;
    final pieces = int.tryParse(byPiecesController.text) ?? 0;

    setState(() {
      pricePerPiece = pieces > 0 ? costPrice / pieces : 0;
    });

    computeInterest(); // always update interest
  }

void computeInterest() {
  if (isPromo) {
    computePromoLogic();
    return;
  }

  final retailPrice = double.tryParse(retailPriceController.text) ?? 0;

  setState(() {
    priceInterest = retailPrice - pricePerPiece;
  });
}


  /// ------------------- SAVE PRODUCT ------------------- ///
  void saveProduct() async {
    final name = nameController.text.trim();
    final costPrice = double.tryParse(costPriceController.text.trim()) ?? 0;
    final retailPrice = double.tryParse(retailPriceController.text.trim()) ?? 0;
    otherQty = int.tryParse(promoQtyController.text.trim()) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter product name")),
      );
      return;
    }

    final online = await productService.isOnline1();
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No internet connection. Cannot save product."),
        ),
      );
      return;
    }

    final exists = await productService.productNameExists(name);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Product $name price: $retailPrice already exists.',
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final localId = await productService.insertProductOffline(
        name: name,
        costPrice: costPrice,
        retailPrice: retailPrice,
        stock: 0,
        isPromo: isPromo,
        otherQty: otherQty,
      );

      if (await productService.isOnline2()) {
        await productService.syncOnlineProducts();
      }

      if (await productService.isOnline1()) {
        await productService.syncSingleProduct(localId);
      }

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            online
                ? "Product added and synced online!"
                : "Product added locally. Will sync when online.",
          ),
        ),
      );

      // Clear fields
      nameController.clear();
      costPriceController.clear();
      byPiecesController.clear();
      retailPriceController.clear();
      promoQtyController.clear();

      setState(() {
        pricePerPiece = 0;
        priceInterest = 0;
        isPromo = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving product: $e")));
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    costPriceController.dispose();
    byPiecesController.dispose();
    retailPriceController.dispose();
    promoQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Product")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text("Promo"),
              value: isPromo,
              onChanged: (val) {
                setState(() => isPromo = val ?? false);
              },
            ),
           if (isPromo)
  TextField(
    controller: promoQtyController,
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(labelText: "Qty for Promo"),
    onChanged: (_) {
      computePromoLogic();
    },
  ),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Product Name"),
            ),
            TextField(
  controller: costPriceController,
  keyboardType: TextInputType.number,
  decoration: const InputDecoration(labelText: "Cost Price"),
  onChanged: (_) {
    computePricePerPiece();
    if (isPromo) computePromoLogic();
  },
),

         TextField(
  controller: byPiecesController,
  keyboardType: TextInputType.number,
  decoration: const InputDecoration(labelText: "By Pieces"),
  onChanged: (_) {
    computePricePerPiece();
    if (isPromo) computePromoLogic();
  },
),

            const SizedBox(height: 10),
           if (!isPromo)
  Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey[200],
        ),
        child: Text('Price per piece: ₱${pricePerPiece.toStringAsFixed(2)}'),
      ),
    ],
  ),

            TextField(
              controller: retailPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Retail Price"),
              onChanged: (_) {
  computeInterest();
  if (isPromo) computePromoLogic();
}

            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey[200],
                  ),
                  child:
                      Text('Interest ₱${priceInterest.toStringAsFixed(2)}'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : saveProduct,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save Product"),
            ),
          ],
        ),
      ),
    );
  }
}
