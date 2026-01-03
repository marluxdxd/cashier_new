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

  // ================= ADD EMPTY ROW =================
  void addEmptyRow() {
    rows.add(POSRow());
  }

  // ================= RESET (IMPORTANT) =================
  void reset() {
    rows = [POSRow()];
  }

  // ================= AUTO FILL ROWS =================
  Future<void> autoFillRows(VoidCallback onUpdate) async {
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.product != null) continue;

      final selectedProduct = await showModalBottomSheet<Productclass>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.0),
        isScrollControlled: true,
        builder: (_) => Productbottomsheet(),
      );

      if (selectedProduct == null) break;

      row.product = selectedProduct;
      row.isPromo = selectedProduct.isPromo;
      row.otherQty = selectedProduct.isPromo ? selectedProduct.otherQty : 0;
      row.qty = 0;

      onUpdate(); // 🔥 IMPORTANT: update UI immediately

      if (row == rows.last) addEmptyRow();

      // Qty sheet only if NOT promo
      if (!row.isPromo) {
        final qty = await showModalBottomSheet<int>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.0),
          builder: (_) => Qtybottomsheet(stock: row.product!.stock),
        );

        if (qty == null) break;
        row.qty = qty;
        onUpdate(); // 🔥 update UI after qty
        if (row == rows.last) addEmptyRow();
      }
    }
  }

  // ================= BUILD ROW =================
  Widget buildRow(
    POSRow row,
    int index, {
    required VoidCallback onUpdate,
    required bool isAutoNextRowOn,
  }) {
    // double displayPrice = 0;
    // if (row.product != null) {
    //   displayPrice = row.isPromo
    //       ? row.product!.price
    //       : row.product!.price * row.qty;

    
    // }

     double displayPrice2 = 0;
     if (row.product != null) {
       displayPrice2 = row.isPromo
           ? row.product!.retailPrice
           : row.product!.retailPrice * row.qty;
     }     

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // ================= PRODUCT =================
          Expanded(
            flex: 6,
            child: InkWell(
              onTap: () async {
                final bool isReselect = row.product != null;

                // 🟢 AUTO FILL — ONLY FOR EMPTY ROW
                if (isAutoNextRowOn && !isReselect) {
                  await autoFillRows(onUpdate);
                  return;
                }

                // 🟡 PRODUCT SELECTION (initial OR reselect)
                final selectedProduct =
                    await showModalBottomSheet<Productclass>(
                      context: context,
                      barrierColor: Colors.black.withOpacity(0.0),
                      isScrollControlled: true,
                      builder: (_) => Productbottomsheet(),
                    );

                // ❌ User closed bottomsheet
                if (selectedProduct == null) return;

                // ✅ APPLY PRODUCT
                row.product = selectedProduct;
                row.isPromo = selectedProduct.isPromo;
                row.otherQty = selectedProduct.isPromo
                    ? selectedProduct.otherQty
                    : 0;
                row.qty = 0;
                onUpdate();

                // 📦 QTY BOTTOMSHEET
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

                // ➕ ALWAYS CONTINUE AUTO NEXT ROW
                if (isAutoNextRowOn) {
                  if (row == rows.last) {
                    addEmptyRow();
                    onUpdate();
                  }

                  // 🔹 AUTO FOCUS: scroll to last row
                  Future.delayed(Duration(milliseconds: 100), () {
                    Scrollable.ensureVisible(
                      context, // provide the row context here
                      duration: Duration(milliseconds: 300),
                      alignment: 0.5,
                    );
                  });
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
                color: row.isPromo ? Colors.grey[200] : Colors.white,
              ),
              child: Text(
                row.isPromo
                    ? row.otherQty.toString()
                    : (row.qty == 0 ? "Qty" : row.qty.toString()),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ================= ROW TOTAL =================
          Text(
            "₱${displayPrice2.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          // ================= DELETE =================
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              rows.removeAt(index);
              if (rows.isEmpty) reset();
              onUpdate();
            },
          ),
        ],
      ),
    );
  }

  // ================= TOTAL BILL =================
  double get totalBill {
    double total = 0;
    for (final row in rows) {
      if (row.product == null) continue;
      final qty = row.isPromo ? row.otherQty : row.qty;
      total += row.product!.retailPrice * qty;
    }
    return total;
  }
}
