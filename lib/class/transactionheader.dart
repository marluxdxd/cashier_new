import 'package:cashier/class/transactionitemclass.dart';

class TransactionHeader {
  final int id;
  final double cash;
  final double change;
  final String createdAt;
  final List<TransactionItem> items;

  TransactionHeader({
    required this.id,
    required this.cash,
    required this.change,
    required this.createdAt,
    required this.items,
  });
}
