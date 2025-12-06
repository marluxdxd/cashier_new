
final List<Productclass> fruits = [
  Productclass(name: 'Apple', price: 10.0, stock: 5),
  Productclass(name: 'Banana', price: 5.0, stock: 10),
  Productclass(name: 'Banene1', price: 3.0, stock: 8),
  Productclass(name: 'Mango', price: 15.0, stock: 2),
];






class Productclass {
  final String name;
  final double price;
  final int stock;

  Productclass({
    required this.name,
    required this.price,
    required this.stock,
  });

  // Add this factory constructor to convert JSON into Productclass


  // Optional: convert Productclass to JSON if needed later

}



