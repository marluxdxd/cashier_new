import 'package:cashier/view/home.dart';
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
            title: Text("Add Productss"),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.list_alt),
            title: Text("View All Products"),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.storefront_sharp),
            title: Text('Stock'),
            onTap: () {
              Navigator.pop(context);
            },
          ),

          ListTile(
            leading: Icon(Icons.history),
            title: Text("History"),
            onTap: () {
              Navigator.pop(context);
            },
          ),

          ListTile(
            leading: Icon(Icons.campaign),
            title: Text("Sales Report"),
            onTap: () {
              Navigator.pop(context);
            },
          ),

          ExpansionTile(
            title: Text("Database"),
            children: [
              ListTile(
                leading: Icon(Icons.backup),
                title: Text("Backup"),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.restore),
                title: Text("Restore"),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
