import 'package:cashier/view/history_stock_screen.dart';
import 'package:cashier/view/home.dart';
import 'package:cashier/view/productview.dart';
import 'package:cashier/view/reports_file/sales_reports_screen.dart';
import 'package:cashier/view/stock_screnn.dart';
import 'package:cashier/view/transaction_history.dart';
import 'package:flutter/material.dart';

class Appdrawer extends StatefulWidget {
  const Appdrawer({super.key});

  @override
  State<Appdrawer> createState() => _AppdrawerState();
}

class _AppdrawerState extends State<Appdrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 200,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.teal[100]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 65, // size of the circle
                  backgroundColor: Colors.white, // optional background color
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: Text('Select Role'),
                          children: [
                            SimpleDialogOption(
                              onPressed: () {
                                Navigator.pop(context); // close the dialog

                                // 🔥 Navigate back to USER MODE
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => Home()),
                                );
                              },
                              child: Text('User'),
                            ),
                            SimpleDialogOption(
                              onPressed: () {
                                Navigator.pop(context); // close the dialog

                                // 🔥 Navigate back to USER MODE
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => Home()),
                                );
                              },
                              child: Text('User'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 100,
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/marhon.png',
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          ListTile(
            leading: Icon(Icons.home),
            title: Text("Home"),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.inventory_rounded),
            title: Text("Add/edit/delete"),
            onTap: () {
              Navigator.push(
                context,
               MaterialPageRoute(builder: (_) => const Productview()),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.storefront_sharp),
            title: Text('Inventory Stock'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InventoryStock()),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.campaign),
            title: Text("Sales Report"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SalesNavigationScreen()),
              );
            },
          ),

          ExpansionTile(
            title: Text("Stock History"),
            children: [
              ListTile(
                leading: Icon(Icons.history),
                title: Text("Stock History"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HistoryScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.history),
                title: Text("Transction History"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransactionHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

         
        ],
      ),
    );
  }
}
