import 'package:cashier/view/reports_file/setdatesales.dart';
import 'package:cashier/view/reports_file/monthlysales.dart';
import 'package:flutter/material.dart';

class SalesNavigationScreen extends StatelessWidget {
  const SalesNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,   // 3 TABS
      child: Scaffold(
        appBar: AppBar(
          title: Text("Reports"),
          bottom: TabBar(
            labelColor: Colors.grey,
            unselectedLabelColor: Colors.black,
            indicatorColor: Colors.red,
            tabs: const [
              Tab(icon: Icon(Icons.shopping_bag), text: "Monthly Sales"),
              Tab(icon: Icon(Icons.calendar_today), text: "Set Date Sales"),
         
            ],
          ),
        ),

        body: const TabBarView(
          children: [
            MonthlySales(),
            SetSaleDateTab(),
          
          ],
        ),
      ),
    );
  }
}

