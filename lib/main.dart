import 'package:cashier/services/connectivity_service.dart';
import 'package:cashier/services/product_service.dart';
import 'package:cashier/services/stock_history_sync.dart';
import 'package:cashier/services/transaction_promo_service.dart';
import 'package:cashier/services/transaction_service.dart';
import 'package:cashier/services/transactionitem_service.dart';
import 'package:cashier/view/home.dart';
import 'package:flutter/material.dart';
import 'package:cashier/database/supabase.dart';
import 'package:cashier/database/local_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await LocalDatabase().database;
  final localDb = LocalDatabase();

  // Tan-awa tanan transactions sa local DB
  await localDb.printAllTransactions();
  await localDb.printAllTransactionItems();

  final productService = ProductService();
  final transactionService = TransactionService();
  final transactionItemService = TransactionItemService();
  final stockHistoryService = StockHistorySyncService(); // create instance
  final transactionPromoService = TransactionPromoService();


  ConnectivityService(
    productService: productService,
    transactionService: TransactionService(),
    transactionItemService: transactionItemService,
    stockHistorySyncService: stockHistoryService,
    transactionPromoService: transactionPromoService,
  ); // auto-listen

  runApp( MyApp());
}

class MyApp extends StatelessWidget {
   MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home:  Home(),
    );
  }
}
