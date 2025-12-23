import 'package:cashier/services/connectivity_service.dart';
import 'package:cashier/services/product_service.dart';
import 'package:cashier/services/stock_history_sync.dart';
import 'package:cashier/services/sync_service.dart';
import 'package:cashier/services/transaction_service.dart';
import 'package:cashier/services/transactionitem_service.dart';
import 'package:cashier/view/home.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cashier/database/supabase.dart';
import 'package:cashier/database/local_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await LocalDatabase().database;

//--------DELETE DB---------------

// final dbPath = await getDatabasesPath();
// final path = join(dbPath, 'app.db');
// await deleteDatabase(path); // deletes existing DB
 final localDb = LocalDatabase();

  // Tan-awa tanan transactions sa local DB
  await localDb.printAllTransactions();

  final productService = ProductService();
  final transactionService = TransactionService ();
  final transactionItemService = TransactionItemService();
final  stockHistoryService = StockHistorySyncService(); // create instance



  ConnectivityService(productService: productService, transactionService: TransactionService(), transactionItemService: transactionItemService, stockHistorySyncService: stockHistoryService); // auto-listen
  



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
