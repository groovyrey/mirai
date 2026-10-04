/// Parses the worker's `broadcast` string (e.g. "Sundays at 23:15 JST") into
/// the next predicted airing instant and renders compact countdown text.
///
/// All airing times on aniwaves are Japan Standard Time (UTC+9, no DST), so
/// the wall clock is interpreted in JST and the returned instant is expressed
/// in UTC, making the countdown correct on any device regardless of its local
/// timezone.
class BroadcastSchedule {
  BroadcastSchedule._();

  static const Duration _jstOffset = Duration(hours: 9);

  static const Map<String, int> _weekdays = {
    'sunday': DateTime.sunday,
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
  };

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _dayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  /// Returns the UTC instant of the next predicted airing, or null when
  /// [broadcast] cannot be parsed. When the weekly slot has already aired
  /// today, the result rolls to next week (or tomorrow for "Daily" shows).
  static DateTime? nextAiringUtc(String broadcast, {DateTime? from}) {
    final now = (from ?? DateTime.now()).toUtc();
    final low = broadcast.trim().toLowerCase();
    if (low.isEmpty) return null;

    int? weekday;
    if (!low.contains('daily')) {
      for (final entry in _weekdays.entries) {
        if (low.contains(entry.key)) {
          weekday = entry.value;
          break;
        }
      }
      if (weekday == null) return null;
    }

    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(low);
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;

    final jstWall = now.add(_jstOffset);
    var days = weekday == null ? 0 : (weekday - jstWall.weekday) % 7;
    var candidate = _airDateTime(jstWall, days, hour, minute);
    if (!candidate.isAfter(now)) {
      candidate = _airDateTime(jstWall, weekday == null ? 1 : 7, hour, minute);
    }
    return candidate;
  }

  /// Builds the absolute UTC instant for a JST wall-clock time that is [days]
  /// ahead of [jstWall] (a UTC DateTime carrying JST wall components).
  static DateTime _airDateTime(
    DateTime jstWall,
    int days,
    int hour,
    int minute,
  ) =>
      DateTime.utc(
        jstWall.year,
        jstWall.month,
        jstWall.day + days,
        hour,
        minute,
      ).subtract(_jstOffset);

  /// Compact countdown like "2d 14h 03m 12s", dropping leading units.
  static String countdownText(Duration remaining) {
    if (remaining < Duration.zero) remaining = Duration.zero;
    final total = remaining.inSeconds;
    final days = total ~/ 86400;
    final hours = (total % 86400) ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final two = (int v) => v.toString().padLeft(2, '0');
    if (days > 0) return '${days}d ${hours}h ${two(minutes)}m ${two(seconds)}s';
    if (hours > 0) return '${hours}h ${two(minutes)}m ${two(seconds)}s';
    if (minutes > 0) return '${minutes}m ${two(seconds)}s';
    return '${seconds}s';
  }

  /// Human label for the predicted airing, shown in JST: "Sun, Oct 11 at
  /// 23:15 JST".
  static String airingLabel(DateTime instantUtc) {
    final jst = instantUtc.toUtc().add(_jstOffset);
    final day = _dayNames[jst.weekday - 1];
    final month = _monthNames[jst.month - 1];
    final hh = jst.hour.toString().padLeft(2, '0');
    final mm = jst.minute.toString().padLeft(2, '0');
    return '$day, $month ${jst.day} at $hh:$mm JST';
  }
}