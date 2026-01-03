import 'package:supabase_flutter/supabase_flutter.dart';

class Productclass {
  final int id;
  final String name;
  final double price;
  final double retailPrice;
  final double costPrice;
  int stock;
  final bool isPromo;
  final int otherQty;
  final String type; // 'add', 'update', 'delete' for sync
  final String productClientUuid;

  Productclass({
    required this.id,
    required this.name,
    required this.price,
    required this.retailPrice,
    required this.costPrice,
    required this.stock,
    required this.productClientUuid, // ✅ REQUIRED
    this.isPromo = false, // default false
    this.otherQty = 0, // default 0
    this.type = 'add',
  });

  // Convert to Map for Supabase insert/update
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'retail_price': retailPrice,
      'cost_price': costPrice,
      'stock': stock,
      'is_promo': isPromo,
      'other_qty': otherQty,
      'client_uuid': productClientUuid,
      'type': type,
    };
  }

  // Convert Supabase row → Productclass
  factory Productclass.fromMap(Map<String, dynamic> map) {
    return Productclass(
      id: map['id'],
      name: map['name'],
      price: map['price'] is int
          ? (map['price'] as int).toDouble()
          : map['price'],
      retailPrice: map['retail_price'] is int
          ? (map['retail_price'] as int).toDouble()
          : map['retail_price'],
      costPrice: map['cost_price'] is int
          ? (map['cost_price'] as int).toDouble()
          : map['cost_price'],
      stock: map['stock'],
      isPromo: map['is_promo'] ?? false,
      otherQty: map['other_qty'] ?? 0,
      productClientUuid: map['client_uuid'] as String,
      type: map['type'] ?? 'add',
    );
  }

  // Fetch all products from Supabase
  static Future<List<Productclass>> fetchProducts() async {
    final data = await Supabase.instance.client.from('products').select();

    return (data as List<dynamic>)
        .map((e) => Productclass.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
