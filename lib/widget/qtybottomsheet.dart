import 'package:flutter/material.dart';

class Qtybottomsheet extends StatefulWidget {
  final int stock; // <-- available stock
  const Qtybottomsheet({super.key, required this.stock});

  @override
  State<Qtybottomsheet> createState() => _QtybottomsheetState();
}

class _QtybottomsheetState extends State<Qtybottomsheet> {
  String input = "";

  final List<int> num = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]; // Example numbers
  late List<int> matchnum;

  @override
  void initState() {
    super.initState();
    matchnum = List.from(num.where((n) => n <= widget.stock));
  }

  void filterNumbers(String value) {
    setState(() {
      input = value;
      matchnum = num
          .where((n) => n.toString().startsWith(value) && n <= widget.stock)
          .toList();
    });
  }

  void selectQty(int selected) {
    if (selected > widget.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Quantity cannot exceed stock (${widget.stock})")),
      );
      return;
    }
    Navigator.pop(context, selected);
    print("You selected: $selected");
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.35,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              TextField(
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter quantity...",
                  prefixIcon: const Icon(Icons.dialpad),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: filterNumbers,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: matchnum.isEmpty
                    ? Center(
                        child: Text(
                          "No available quantity",
                          style: TextStyle(color: Colors.red),
                        ),
                      )
                    : ListView.builder(
                        itemCount: matchnum.length,
                        itemBuilder: (_, index) {
                          return ListTile(
                            title: Text(matchnum[index].toString()),
                            onTap: () => selectQty(matchnum[index]),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Optional helper class for type safety
class SelectedQty {
  final int qty;

  SelectedQty({required this.qty});
}
