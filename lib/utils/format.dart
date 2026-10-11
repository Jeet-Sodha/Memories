import 'package:intl/intl.dart';

String formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d.toLocal());
String formatDateLong(DateTime d) =>
    DateFormat('MMMM d, yyyy').format(d.toLocal());
String monthLabel(DateTime d) =>
    DateFormat('MMMM yyyy').format(d.toLocal()).toUpperCase();
String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d.toLocal());

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
