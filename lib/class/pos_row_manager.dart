import 'package:flutter/material.dart';
import '../class/productclass.dart';
import '../class/posrowclass.dart';
import '../widget/productbottomsheet.dart';
import '../widget/qtybottomsheet.dart';

class POSRowManager {
  final BuildContext context;

  POSRowManager(this.context) {
    rows = [POSRow()];
  }

  late List<POSRow> rows;
  Map<int, int> promoCountByProduct = {};

  // ================= ADD EMPTY ROW =================
  void addEmptyRow() {
    rows.add(POSRow());
    print("addEmptyRow() called → total rows: ${rows.length}");
  }

  // ================= RESET =================
  void reset() {
    rows = [POSRow()];
  }

  void reset2() {
    rows = [POSRow()];
    promoCountByProduct.clear();
    print("♻️ RESET → rows & promo counts cleared");
  }

  // ================= AUTO FILL ROWS =================
  Future<void> autoFillRows(VoidCallback onUpdate) async {
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.product != null) continue;

      Productclass? selectedProduct;

while (true) {
  selectedProduct = await showModalBottomSheet<Productclass>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.0),
    isScrollControlled: true,
    builder: (_) => Productbottomsheet(),
  );

  if (selectedProduct == null) break;

  // Prevent duplicate selection
  final alreadySelected = rows.any(
    (r) => r.product?.id == selectedProduct!.id,
  );

  if (alreadySelected) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Product already selected in another row!"),
        duration: Duration(seconds: 1),
      ),
    );
    continue; // ask user to pick again
  }

  break; // valid product selected
}

if (selectedProduct == null) break; // user cancelled
row.product = selectedProduct;
row.isPromo = selectedProduct.isPromo;


      if (selectedProduct == null) break;

      row.product = selectedProduct;
      row.isPromo = selectedProduct.isPromo;

      // Initialize promo_count correctly
      if (row.isPromo) {
        row.promo_count = 1; // start with 1
        row.otherQty = selectedProduct.otherQty; // per promo qty
        promoCountByProduct[row.product!.id] = row.promo_count;
        print(
          "🎁 PROMO ADDED → ID:${row.product!.id} count:${row.promo_count}",
        );
      } else {
        row.qty = 1;
        row.otherQty = 0;
      }

      onUpdate();

      if (row == rows.last) addEmptyRow();

      if (!row.isPromo) {
        final qty = await showModalBottomSheet<int>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.0),
          builder: (_) => Qtybottomsheet(stock: row.product!.stock),
        );

        if (qty == null) break;
        row.qty = qty;
        onUpdate();
        if (row == rows.last) addEmptyRow();
      }
    }
  }

  // ================= MINI QTY CONTROLS =================
  Widget _buildQuantityControls(POSRow row, VoidCallback onUpdate) {
    // baseQty = per promo qty gikan sa product
    int baseQty = row.isPromo ? row.product?.otherQty ?? 1 : 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () {
            if (row.isPromo) {
              if (row.promo_count > 1) {
                row.promo_count--;
                row.otherQty = row.promo_count * baseQty;

                // Sync map
                promoCountByProduct[row.product!.id] = row.promo_count;
                print(
                  "🎁 PROMO DECREASED → ID:${row.product!.id} count:${row.promo_count}",
                );
              }
            } else {
              if (row.qty > 1) row.qty--;
            }
            onUpdate();
          },
        ),
        Text(
          row.isPromo ? row.promo_count.toString() : row.qty.toString(),
          style: const TextStyle(fontSize: 16),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () {
            if (row.isPromo) {
              row.promo_count++;
              row.otherQty = row.promo_count * baseQty;

              // Sync map
              promoCountByProduct[row.product!.id] = row.promo_count;
              print(
                "🎁 PROMO INCREASED → ID:${row.product!.id} count:${row.promo_count}",
              );
            } else {
              row.qty++;
            }
            onUpdate();
          },
        ),
      ],
    );
  }

  // ================= BUILD ROW =================
  Widget buildRow(
    POSRow row,
    int index, {
    required VoidCallback onUpdate,
    required bool isAutoNextRowOn,
  }) {
    double displayPrice = 0;
    if (row.product != null) {
      displayPrice = row.isPromo
          ? row.product!.retailPrice * row.promo_count
          : row.product!.retailPrice * row.qty;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ================= PRODUCT =================
                Expanded(
                  flex: 6,
                  child: InkWell(
                 onTap: () async {
  // If product is already selected in THIS row, do nothing
  if (row.product != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Product already selected, cannot change."),
        duration: Duration(seconds: 1),
      ),
    );
    return;
  }

  // Show product selection sheet
  final selectedProduct = await showModalBottomSheet<Productclass>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.0),
    isScrollControlled: true,
    builder: (_) => Productbottomsheet(),
  );

  if (selectedProduct == null) return;

  // Prevent duplicate selection across rows
  final alreadySelected = rows.any(
    (r) => r != row && r.product?.id == selectedProduct.id,
  );

  if (alreadySelected) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Product already selected in another row!"),
        duration: Duration(seconds: 1),
      ),
    );
    return;
  }

  // Assign product to current row
  row.product = selectedProduct;
  row.isPromo = selectedProduct.isPromo;

  if (row.isPromo) {
    row.promo_count = 1;
    row.otherQty = selectedProduct.otherQty;
    promoCountByProduct[row.product!.id] = row.promo_count;
    print(
      "🎁 PROMO SELECTED → ID:${row.product!.id} count:${row.promo_count}",
    );
  } else {
    row.qty = 1;
    row.otherQty = 0;
  }

  onUpdate();

  // Ask for quantity if not promo
  if (!row.isPromo) {
    final qty = await showModalBottomSheet<int>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.0),
      builder: (_) => Qtybottomsheet(stock: row.product!.stock),
    );

    if (qty != null) {
      row.qty = qty;
      onUpdate();
    }
  }

  // ✅ AUTO NEXT ROW ONLY if current row is the last one
  if (isAutoNextRowOn && row == rows.last) {
    addEmptyRow();
    onUpdate();
  }

  // ✅ Fill empty rows automatically if enabled
  if (isAutoNextRowOn) {
    await autoFillRows(onUpdate);
  }
},

                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(row.product?.name ?? "Select Product"),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // ================= QTY =================
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                      color: row.isPromo ? Colors.grey[200] : Colors.grey[200],
                    ),
                    child: Text(
                      row.isPromo ? row.otherQty.toString() : row.qty.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // ================= ROW TOTAL =================
                Text(
                  "₱${displayPrice.toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                // ================= DELETE =================
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    final removedRow = rows[index];

                    if (removedRow.isPromo && removedRow.product != null) {
                      final productId = removedRow.product!.id;
                      promoCountByProduct.remove(productId);

                      print(
                        "❌ PROMO REMOVED → ID:$productId",
                      );
                    }

                    rows.removeAt(index);
                    if (rows.isEmpty) reset();
                    onUpdate();
                  },
                ),
              ],
            ),

            const SizedBox(height: 6),

            _buildQuantityControls(row, onUpdate),
          ],
        ),
      ),
    );
  }

  // ================= TOTAL BILL =================
  double get totalBill {
    double total = 0;
    for (var row in rows) {
      if (row.product != null) {
        total += row.isPromo
            ? row.product!.retailPrice * row.promo_count
            : row.product!.retailPrice * row.qty;
      }
    }
    return total;
  }
}
