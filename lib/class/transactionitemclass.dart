class TransactionItem {
  final int transactionId;
  final int productId;
  final String productName;
  final int qty;
  final double price;

  TransactionItem({
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.price,
  });
}