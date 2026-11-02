import 'package:intl/intl.dart';

/// Home list timestamp: time today, date otherwise.
String formatConversationTime(int epochMs, {DateTime? now}) {
  final time = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final reference = now ?? DateTime.now();
  if (time.year == reference.year && time.month == reference.month && time.day == reference.day) {
    return DateFormat.Hm().format(time);
  }
  if (time.year == reference.year) return DateFormat('d MMM').format(time);
  return DateFormat('d MMM y').format(time);
}

bool isSameDay(int epochMsA, int epochMsB) {
  final a = DateTime.fromMillisecondsSinceEpoch(epochMsA);
  final b = DateTime.fromMillisecondsSinceEpoch(epochMsB);
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Chat date separator: "Today", "Yesterday", weekday, or full date.
String formatDayLabel(int epochMs, {DateTime? now}) {
  final time = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return DateFormat.EEEE().format(time);
  if (time.year == reference.year) return DateFormat('d MMMM').format(time);
  return DateFormat('d MMMM y').format(time);
}

/// Message bubble timestamp.
String formatMessageTime(int epochMs) =>
    DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(epochMs));
