
import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteDB {
  final client = Supabase.instance.client;

  Future<void> deleteProductOnline(int id) async {
    final res = await client
        .from('products')
        .delete()
        .eq('id', id);

    if (res.error != null) {
      throw Exception(res.error!.message);
    }
  }
}
