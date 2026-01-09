import 'package:cashier/widget/addproduct.dart';
import 'package:flutter/material.dart';

class Productview extends StatefulWidget {
  const Productview({super.key});

  @override
  State<Productview> createState() => _ProductviewState();
}

class _ProductviewState extends State<Productview> {
 bool isLoading = false;
List<Map<String, dynamic>> filteredProducts = [
  {
    'id': 1,
    'name': 'Product A',
    'stock': 10,
    'retail_price': 100.0,
    'is_promo': 1,
  },
  {
    'id': 2,
    'name': 'Product B',
    'stock': 5,
    'retail_price': 250.0,
    'is_promo': 0,
  },
];




  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Products')),
      body: Column(
      ),

        floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductPage()),
          );
        },
        child: const Icon(Icons.add),
      ),

    );
  }
}



