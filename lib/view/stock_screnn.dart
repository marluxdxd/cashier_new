import 'package:cashier/view/inventory_file/tab1.dart';
import 'package:cashier/view/inventory_file/tab2.dart';
import 'package:flutter/material.dart';

class InventoryStock extends StatelessWidget {
  const InventoryStock({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,   // 3 TABS
      child: Scaffold(
        appBar: AppBar(
          title: Text("Inventory"),
          bottom: TabBar(
            labelColor: Colors.grey,
            unselectedLabelColor: Colors.black,
            indicatorColor: Colors.red,
            tabs: const [
              Tab(icon: Icon(Icons.shopping_bag), text: "Edit Stock"),
              Tab(icon: Icon(Icons.calendar_today), text: "stock"),
         
            ],
          ),
        ),

        body: const TabBarView(
          children: [
            StockScreen(),
            StockScreen2(),
          
          ],
        ),
      ),
    );
  }
}