/// "1 page", "3 pages".
String plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// Drawing time for stats: "<1m" once anything is drawn, "45m", "2h 40m".
String formatDrawn(Duration d) {
  if (d == Duration.zero) return '0m';
  if (d < const Duration(minutes: 1)) return '<1m';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
