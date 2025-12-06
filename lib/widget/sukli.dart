import 'package:flutter/material.dart';

class Sukli extends StatelessWidget {
  final double change;

  const Sukli({super.key, required this.change});

  @override
  Widget build(BuildContext context) {
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Center(
        child: Column(
          children: [
            Text(
              'SUKLI',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 15),
            Text(
              change.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 170,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
