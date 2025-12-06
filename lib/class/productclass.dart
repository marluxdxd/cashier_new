class Productclass {
  int? id;  // This will be nullable since it's auto-incremented in SQLite
  final String name;
  final double price;
  final int stock;

  Productclass({
    this.id,  // Allow id to be null so SQLite can auto-increment it
    required this.name,
    required this.price,
    required this.stock,
  });

  // Convert a Productclass into a Map. The keys must match the column names in your database.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'stock': stock,
    };
  }

  // Convert a Map into a Productclass. This is used when retrieving a product from the database.
  factory Productclass.fromMap(Map<String, dynamic> map) {
    return Productclass(
      id: map['id'],  // The id is fetched from the database (auto-incremented)
      name: map['name'],
      price: map['price'],
      stock: map['stock'],
    );
  }
}
