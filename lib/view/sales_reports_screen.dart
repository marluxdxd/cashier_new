import 'package:flutter/material.dart';

class SalesNavigationScreen extends StatelessWidget {
  const SalesNavigationScreen({Key? key}) : super(key: key);

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

// ------------------ TAB 1: SALES ------------------
class SalesTab extends StatelessWidget {
  const SalesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("Sales Content Here",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }
}

// ------------------ TAB 2: PAYMENTS ------------------
class PaymentsTab extends StatelessWidget {
  const PaymentsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("Payments Content Here",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }
}

// ------------------ TAB 3: CHARTS ------------------
class ChartsTab extends StatelessWidget {
  const ChartsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("Charts Content Here",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }
}
