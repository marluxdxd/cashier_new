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
// Converts a UTC datetime string to Philippine Time and formats it
String formatToPHT(String? utcString) {
  if (utcString == null) return '';
  final utcTime = DateTime.parse(utcString).toUtc();
  final phtTime = utcTime.add(const Duration(hours: 8));
  return DateFormat('yyyy-MM-dd hh:mm a').format(phtTime);
}
/// New function to format only time
// String formatToPHTTimeOnly(String? utcString) {
//   if (utcString == null) return '';
//   final utcTime = DateTime.parse(utcString).toUtc();
//   final phtTime = utcTime.add(const Duration(hours: 8));
//   return DateFormat('hh:mm a').format(phtTime); // only time, 12-hour format
// }
