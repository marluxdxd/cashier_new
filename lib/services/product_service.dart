import 'package:cashier/database/supabase.dart';

class ProductService {
  final supabase = SupabaseConfig.supabase;

  // CREATE
  Future<void> addProduct(String name, double price, int stock) async {
    await supabase.from('products').insert({
      'name': name,
      'price': price,
      'stock': stock,
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
