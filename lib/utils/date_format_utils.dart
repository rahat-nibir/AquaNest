import 'package:intl/intl.dart';

/// 'Today' / 'Yesterday' / 'N days ago' — used anywhere a feeding-history
/// or activity-log timestamp needs a human-friendly relative label.
String relativeDayLabel(DateTime dt) {
  final now = DateTime.now();
  final diff = DateTime(now.year, now.month, now.day)
      .difference(DateTime(dt.year, dt.month, dt.day))
      .inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '$diff days ago';
}

/// Locale-aware clock time, e.g. "5:08 PM".
String clockTimeLabel(DateTime dt) => DateFormat.jm().format(dt);
