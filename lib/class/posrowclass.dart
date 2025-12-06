import 'package:cashier/class/productclass.dart';


List<POSRow> rows = [POSRow()]; // always start with 1 empty row


class POSRow {
  Productclass? product;
  int qty;

  POSRow({this.product, this.qty = 0});
}
