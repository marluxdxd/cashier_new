class ProductOffline {
  final int id;

  // For product item
  final int productId;
  final String? productName;
  final double? price;
  final int? qty;

  final bool isPromo;
  final int otherQty;

  // For full transaction
  final double? total;
  final double? cash;
  final double? change;
  final DateTime? timestamp;

  final List<ProductOffline> items;

  ProductOffline({
    required this.id,
    required this.productId,
    this.productName,
    this.price,
    this.qty,
    this.total,
    this.cash,
    this.change,
    this.timestamp,
    this.items = const [],
    this.isPromo = false,
    this.otherQty = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'qty': qty,
      'is_promo': isPromo ? 1 : 0,
      'other_qty': otherQty,
      'total': total,
      'cash': cash,
      'change': change,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  factory ProductOffline.fromMap(Map<String, dynamic> map) {
    return ProductOffline(
      id: map['id'],
      productId: map['product_id'],
      productName: map['product_name'],
      price: (map['price'] as num?)?.toDouble(),
      qty: map['qty'],
      isPromo: map['is_promo'] == 1,
      otherQty: map['other_qty'] ?? 0,
      total: (map['total'] as num?)?.toDouble(),
      cash: (map['cash'] as num?)?.toDouble(),
      change: (map['change'] as num?)?.toDouble(),
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : null,
    );
  }
}
