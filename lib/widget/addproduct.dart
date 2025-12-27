import 'package:cashier/services/product_service.dart';
import 'package:flutter/material.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();
  final promoQtyController = TextEditingController();

  final productService = ProductService();

  bool isLoading = false;
  bool isPromo = false; // default wala promo
  int otherQty = 0;

  /// ------------------- SAVE PRODUCT ------------------- ///
  void saveProduct() async {
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim()) ?? 0;
    final stock = int.tryParse(stockController.text.trim()) ?? 0;
    otherQty = int.tryParse(promoQtyController.text.trim()) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter product name")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1️⃣ Save offline first
      final localId = await productService.insertProductOffline(
        name: name,
        price: price,
        stock: stock,
        isPromo: isPromo,
        otherQty: otherQty,
      );

      // 2️⃣ Check connectivity and sync all offline products
      if (await productService.isOnline2()) {
        await productService.syncOnlineProducts();
      }

      // 3️⃣ Sync this single product immediately if online
      if (await productService.isOnline1()) {
        await productService.syncSingleProduct(localId);
      }

      setState(() => isLoading = false);

      // 4️⃣ Show user feedback
      final online = await productService.isOnline1();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            online
                ? "Product added and synced online!"
                : "Product added locally. Will sync when online.",
          ),
        ),
      );

      nameController.clear();
      priceController.clear();
      stockController.clear();
      promoQtyController.clear();
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
    priceController.dispose();
    stockController.dispose();
    promoQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Product")),
      body: Padding(
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
              ),


              
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Product Name"),
            ),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Price"),
            ),
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Stock"),
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
