/// Formats timestamps for the calm, compact history and draft cards.
String formatUpdatedAt(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final time = '${_two(local.hour)}:${_two(local.minute)}';

  if (day == today) return '今天 $time';
  if (day == today.subtract(const Duration(days: 1))) return '昨天 $time';

  if (local.year == now.year) {
    return '${local.month}月${local.day}日 $time';
  }
  return '${local.year}年${local.month}月${local.day}日';
}

String _two(int value) => value.toString().padLeft(2, '0');
