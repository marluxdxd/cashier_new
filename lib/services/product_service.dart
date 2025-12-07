import 'package:cashier/class/productclass.dart';
import 'package:cashier/database/supabase.dart';

class ProductService {
  final supabase = SupabaseConfig.supabase;

  // Kuhaon tanan products gikan sa 'products' table
  Future<List<Productclass>> fetchProducts() async {
    final data = await supabase
        .from('products')
        .select()
        .order('name'); // optional: i-sort by name

    // Convert sa data ngadto sa Productclass object
    return (data as List<dynamic>)
        .map((e) => Productclass.fromMap(e as Map<String, dynamic>))
        .toList();
  }



  // CREATE
  Future<void> addProduct(String name, double price, int stock, bool isPromo, int otherQty) async {
    await supabase.from('products').insert({
      'name': name,
      'price': price,
      'stock': stock,
      'is_promo': isPromo,
      'other_qty': otherQty,

    
    });
  }

  // READ
  Future<List<Map<String, dynamic>>> getProducts() async {
    final data = await supabase.from('products').select();
    return List<Map<String, dynamic>>.from(data);
  }

  // UPDATE
  Future<void> updateStock(int id, int newStock) async {
    await supabase.from('products').update({
      'stock': newStock,
    }).eq('id', id);
  }

  // DELETE
  Future<void> deleteProduct(int id) async {
    await supabase.from('products').delete().eq('id', id);
  }

  
}
