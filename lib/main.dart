import 'package:cashier/services/product_service.dart';
import 'package:cashier/view/home.dart';
import 'package:flutter/material.dart';
import 'package:cashier/database/supabase.dart';
import 'package:cashier/database/local_db.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //--------------LOCAL-----------------------//
   // 1️⃣ Initialize Supabase first
  await SupabaseConfig.initialize(); 

  // 2️⃣ Now safe to use Supabase
  final service = ProductService();

  // 3️⃣ Sync data from Supabase to local SQLite
  await service.syncProducts();

  // 4️⃣ Run the app
  runApp(const MyApp());
  
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Home(),
    );
  }
}
