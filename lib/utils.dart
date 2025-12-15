// lib/utils.dart
import 'package:intl/intl.dart';

String getPhilippineTimestamp() {
  final nowUtc = DateTime.now().toUtc();
  final philippineTime = nowUtc.add(Duration(hours: 8));
  return philippineTime.toIso8601String();
}

String getPhilippineTimestampFormatted() {
  final nowUtc = DateTime.now().toUtc();
  final philippineTime = nowUtc.add(Duration(hours: 8));
  return DateFormat('yyyy-MM-dd HH:mm:ss').format(philippineTime);
}
