import 'package:cashier/view/home.dart';
import 'package:flutter/material.dart';
import 'package:cashier/database/supabase.dart';
import 'package:cashier/database/offline_service.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();


   //-------------SUPABASE--------------------//
  await SupabaseConfig.initialize();
  //-----------------------------------------//
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
