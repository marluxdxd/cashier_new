// class TransactionItem {
//   final int id;
//   final int productId;
//   final String productName;
//   final int qty;
//   final double price;
//   final bool isPromo;
//   final int otherQty;

//   TransactionItem({
//     required this.id,
//     required this.productId,
//     required this.productName,
//     required this.qty,
//     required this.price,
//     required this.isPromo,
//     required this.otherQty,
//   });

//   factory TransactionItem.fromMap(Map<String, dynamic> map) {
//     return TransactionItem(
//       id: map['item_id'],
//       productId: map['product_id'],
//       productName: map['product_name'],
//       qty: map['qty'],
//       price: map['price'],
//       isPromo: map['is_promo'] == 1,
//       otherQty: map['other_qty'] ?? 0,
//     );
//   }
// }
