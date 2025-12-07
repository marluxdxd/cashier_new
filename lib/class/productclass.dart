import 'package:supabase_flutter/supabase_flutter.dart';

class Productclass {
  final int? id;  
  final String name;
  final double price;
  final int stock;

  Productclass({
    this.id,
    required this.name,
    required this.price,
    required this.stock,
  });

  // Convert to Map for Supabase insert/update
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
    };
  }

  // Convert Supabase row → Productclass
  factory Productclass.fromMap(Map<String, dynamic> map) {
    return Productclass(
      id: map['id'],
      name: map['name'],
      price: map['price'] is int ? (map['price'] as int).toDouble() : map['price'],
      stock: map['stock'],
    );
  }


  // Fetch all products from Supabase
  static Future<List<Productclass>> fetchProducts() async {
    final data = await Supabase.instance.client
        .from('products')
        .select();

    return (data as List<dynamic>).map((e) => Productclass.fromMap(e as Map<String, dynamic>)).toList();
  }

}
