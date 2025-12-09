import 'package:cashier/class/quantityclass.dart';
import 'package:flutter/material.dart';

class Qtybottomsheet extends StatefulWidget {
  const Qtybottomsheet({super.key});

  @override
  State<Qtybottomsheet> createState() => _QtybottomsheetState();
}

class _QtybottomsheetState extends State<Qtybottomsheet> {


String input = "";


  @override
  void initState() {
    super.initState();
    matchnum = List.from(num); // Initialize list at startup
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.30,
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 5,
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Enter quantity...",
                  prefixIcon: Icon(Icons.dialpad),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    input = value;

                    matchnum = num.where((n) {
                      return n.toString().startsWith(value);
                    }).toList();
                  });
                },
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: matchnum.length,
                  itemBuilder: (_, index) {
                    return ListTile(
                      title: Text(matchnum[index].toString()),
                       onTap: () {
                        FocusScope.of(context).unfocus(); // hide keyboard
          Navigator.pop(context, matchnum[index]); // return selected number
            print("You tapped: ${matchnum[index]}");
        },
                      );
                    
                  },
                ),
              ),
              //   child: ListTile(
              //     title: Text('1'),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
