import 'package:cashier/view/reports_file/charts.dart';
import 'package:cashier/view/reports_file/payments.dart';
import 'package:cashier/view/reports_file/sales_tab.dart';
import 'package:flutter/material.dart';

class SalesNavigationScreen extends StatelessWidget {
  const SalesNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,   // 3 TABS
      child: Scaffold(
        appBar: AppBar(
          title: Text("Reports"),
          bottom: TabBar(
            labelColor: Colors.grey,
            unselectedLabelColor: Colors.black,
            indicatorColor: Colors.red,
            tabs: const [
              Tab(icon: Icon(Icons.shopping_bag), text: "Sales"),
              Tab(icon: Icon(Icons.payments), text: "Payments"),
              Tab(icon: Icon(Icons.bar_chart), text: "Charts"),
            ],
          ),
        ),

        body: const TabBarView(
          children: [
            SalesTab(),
            PaymentsTab(),
            ChartsTab(),
          ],
        ),
      ),
    );
  }
}

