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
          continue;
        }

        break;
      }

      if (selectedProduct == null) break;

      row.product = selectedProduct;
      row.isPromo = selectedProduct.isPromo;

      if (row.isPromo) {
        row.promo_count = 1;
        row.otherQty = selectedProduct.otherQty;
        promoCountByProduct[row.product!.id] = row.promo_count;
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
    int baseQty = row.isPromo ? row.product?.otherQty ?? 1 : 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () {
            if (row.isPromo) {
              if (row.promo_count > 1) {
                row.promo_count--;
                row.otherQty = row.promo_count * baseQty;
                promoCountByProduct[row.product!.id] = row.promo_count;
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
              promoCountByProduct[row.product!.id] = row.promo_count;
            } else {
              row.qty++;
            }
            onUpdate();
          },
        ),
      ],
    );
  }

  // ================= BUILD ROW WITH SWIPE =================
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

  final isWideScreen = MediaQuery.of(context).size.width > 600; // adjust threshold
  final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

  Widget rowContent = Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ================= PRODUCT NAME =================
        Flexible(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () async {
                if (row.product != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Product already selected, cannot change."),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  return;
                }

                final selectedProduct = await showModalBottomSheet<Productclass>(
                  context: context,
                  barrierColor: Colors.black.withOpacity(0.0),
                  isScrollControlled: true,
                  builder: (_) => Productbottomsheet(),
                );

                if (selectedProduct == null) return;

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

                row.product = selectedProduct;
                row.isPromo = selectedProduct.isPromo;

                if (row.isPromo) {
                  row.promo_count = 1;
                  row.otherQty = selectedProduct.otherQty;
                  promoCountByProduct[row.product!.id] = row.promo_count;
                } else {
                  row.qty = 1;
                  row.otherQty = 0;
                }

                onUpdate();

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

                if (isAutoNextRowOn && row == rows.last) {
                  addEmptyRow();
                  onUpdate();
                }

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
        ),

        const SizedBox(width: 8),

        // ================= QTY BOX =================
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey[200],
          ),
          child: Text(
            row.isPromo ? row.otherQty.toString() : row.qty.toString(),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(width: 8),

        // ================= MINI CONTROLS =================
        _buildQuantityControls(row, onUpdate),

        const SizedBox(width: 8),

        // ================= ROW TOTAL =================
        Text(
          "₱${displayPrice.toStringAsFixed(2)}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        // ================= DELETE BUTTON FOR WIDE SCREEN =================
        if (isWideScreen || isLandscape)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              if (row.isPromo && row.product != null) {
                promoCountByProduct.remove(row.product!.id);
              }
              rows.removeAt(index);
              if (rows.isEmpty) reset();
              onUpdate();
            },
          ),
      ],
    ),
  );

  // For small screens / portrait → Dismissible
  if (!isWideScreen && !isLandscape) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Dismissible(
        key: ValueKey(row.hashCode),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) {
          if (row.isPromo && row.product != null) {
            promoCountByProduct.remove(row.product!.id);
          }
          rows.removeAt(index);
          if (rows.isEmpty) reset();
          onUpdate();
        },
        child: rowContent,
      ),
    );
  }

  // Otherwise, just return normal row with delete button
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: rowContent,
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
