import 'package:flutter/material.dart';

class PaymentsTab extends StatelessWidget {
  const PaymentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("Payments Content Here",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }
}