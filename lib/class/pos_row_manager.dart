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

  // 🔥 TRACK PROMO COUNT PER PRODUCT
  final Map<int, int> productPromoCount = {}; // key: productId, value: count

  // ================= ADD EMPTY ROW =================
  void addEmptyRow() {
    rows.add(POSRow());
    print("addEmptyRow() called → total rows: ${rows.length}");
  }

  // ================= RESET (IMPORTANT) =================
  void reset() {
    rows = [POSRow()];
    productPromoCount.clear();
  }

  void reset_promoCount() {
    productPromoCount.clear();
    print("♻️ RESET → promo counts cleared");
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
      row.qty = 0;

      // ✅ HANDLE PROMO COUNT PER PRODUCT
      if (row.isPromo) {
        final currentCount = productPromoCount[selectedProduct.id] ?? 0;
        productPromoCount[selectedProduct.id] = currentCount + 1;
        row.otherQty = productPromoCount[selectedProduct.id]!;
        print(
            "🎁 PROMO ADDED → ID: ${row.product!.id}, Name: ${row.product!.name}, Count: ${row.otherQty}");
      } else {
        row.otherQty = 0;
      }

      onUpdate(); // 🔥 update UI immediately

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
    double displayPrice = 0;
    if (row.product != null) {
      displayPrice =
          row.isPromo ? row.product!.retailPrice : row.product!.retailPrice * row.qty;
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

                if (isAutoNextRowOn && !isReselect) {
                  await autoFillRows(onUpdate);
                  return;
                }

                final selectedProduct = await showModalBottomSheet<Productclass>(
                  context: context,
                  barrierColor: Colors.black.withOpacity(0.0),
                  isScrollControlled: true,
                  builder: (_) => Productbottomsheet(),
                );

                if (selectedProduct == null) return;

                row.product = selectedProduct;
                row.isPromo = selectedProduct.isPromo;
                row.qty = 0;

                if (row.isPromo) {
                  final currentCount = productPromoCount[selectedProduct.id] ?? 0;
                  productPromoCount[selectedProduct.id] = currentCount + 1;
                  row.otherQty = productPromoCount[selectedProduct.id]!;
                  print(
                      "🎁 PROMO ADDED → ID: ${row.product!.id}, Name: ${row.product!.name}, Count: ${row.otherQty}");
                } else {
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

                if (isAutoNextRowOn) {
                  if (row == rows.last) {
                    addEmptyRow();
                    onUpdate();
                  }
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
                final currentCount = productPromoCount[productId] ?? 1;
                productPromoCount[productId] = currentCount - 1;
                print("❌ PROMO REMOVED → ID: $productId, count now: ${productPromoCount[productId]}");
              }

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
    for (var row in rows) {
      if (row.product != null) {
        if (row.isPromo) {
          total += row.product!.retailPrice;
        } else {
          total += row.product!.retailPrice * row.qty;
        }
      }
    }
    return total;
  }
}
