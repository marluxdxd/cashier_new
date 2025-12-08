class TransactionItems {
  final int id;
  final int transactionId;
  final int productId;
  final String productName;
  final int qty;
  final double price;
  final bool isPromo;
  final int otherQty;

  TransactionItems({
    required this.id,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.price,
    required this.isPromo,
    required this.otherQty,
  });

  factory TransactionItems.fromMap(Map<String, dynamic> map) {
    return TransactionItems(
      id: map['item_id'] ?? map['id'],
      transactionId: map['transaction_id'],
      productId: map['product_id'],
      productName: map['product_name'] ?? "",
      qty: map['qty'],
      price: (map['price'] as num).toDouble(),
      isPromo: map['is_promo'] == 1,
      otherQty: map['other_qty'] ?? 0,
    );
  }
}
