import 'package:cashier/services/stock_history_sync.dart';
import 'package:cashier/services/transaction_service.dart';
import 'package:cashier/services/transactionitem_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'product_service.dart';

class ConnectivityService {
  final ProductService productService;
  final TransactionService transactionService;
  final TransactionItemService transactionItemService;
  final StockHistorySyncService stockHistorySyncService;

  ConnectivityService({required this.productService, required this.transactionService, required this.transactionItemService, required this.stockHistorySyncService}) {
    _startListening();
  }

  void _startListening() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      if (result != ConnectivityResult.none) {
        print("Device is online! Syncing offline products...");
        await productService.syncOfflineProducts();
        await transactionService.syncOfflineTransactions(); // auto-sync transactions
    
        print("Check synced items in local DB:");
final syncedItems = await transactionItemService.getTransactionItemsOffline(1);
for (var item in syncedItems) {
  print(item);
}
      } else {
        print("Device is offline.");
      }
    });
  }
}
