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

/// Compact "just now" / "12s ago" / "3m ago" label for things that
/// update on the order of seconds-to-minutes, like the camera AI's
/// last analysis timestamp — relativeDayLabel above is day-granularity
/// and would just say "Today" for all of those.
String shortRelativeTimeLabel(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 5) return 'just now';
  if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
