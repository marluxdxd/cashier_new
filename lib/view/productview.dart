import 'package:cashier/widget/addproduct.dart';
import 'package:flutter/material.dart';

class Productview extends StatefulWidget {
  const Productview({super.key});

  @override
  State<Productview> createState() => _ProductviewState();
}

class _ProductviewState extends State<Productview> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: Column(),
       floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductPage()),);
          // ).then((_) => loadProducts()); // refresh after adding
        },
        child: const Icon(Icons.add),
      ),
    );
    
  }
}



