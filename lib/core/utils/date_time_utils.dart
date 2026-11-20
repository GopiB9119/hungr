import '../constants/business_rules.dart';

/// IST (UTC+5:30) Date and Time Utilities for 9:00 PM Cutoff & Lifecycle Tracking
class DateTimeUtils {
  DateTimeUtils._();

  static const _istOffset = Duration(hours: 5, minutes: 30);

  /// IST calendar fields for display, not a UTC instant.
  static DateTime nowIst({DateTime? instant}) =>
      (instant ?? DateTime.now()).toUtc().add(_istOffset);

  static DateTime _todayCutoffUtc(DateTime instant) {
    final day = nowIst(instant: instant);
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
      BusinessRules.cutoffHour,
      BusinessRules.cutoffMinute,
    ).subtract(_istOffset);
  }

  /// The next 9:00 PM IST cutoff, as an actual UTC instant.
  static DateTime nextCutoffIst({DateTime? instant}) {
    final now = instant ?? DateTime.now();
    final today = _todayCutoffUtc(now);
    return now.isBefore(today) ? today : today.add(const Duration(days: 1));
  }

  /// Returns duration remaining until the upcoming 9:00 PM IST cutoff
  static Duration timeRemainingUntilCutoff({DateTime? instant}) {
    final now = instant ?? DateTime.now();
    return nextCutoffIst(instant: now).difference(now);
  }

  /// Checks if current time is in the final 30 minutes before 9:00 PM (8:30 PM - 9:00 PM IST)
  static bool isCutoffUrgent({DateTime? instant}) {
    final remaining = timeRemainingUntilCutoff(instant: instant);
    return remaining <=
        const Duration(minutes: BusinessRules.warningThresholdMinutes);
  }

  /// Verifies if a meal ticket for tomorrow can still be skipped or modified
  /// Server/Client gate: hard lock at 21:00:00 IST
  static bool canModifyTomorrowMeal({DateTime? instant}) {
    final now = instant ?? DateTime.now();
    return now.isBefore(_todayCutoffUtc(now));
  }

  static bool canSkipMeal(DateTime serviceDate, {required DateTime instant}) {
    if (!canModifyTomorrowMeal(instant: instant)) return false;
    final today = nowIst(instant: instant);
    // Timestamps and zoned ISO strings decode as UTC instants. Unzoned dates
    // carry the service day's calendar fields, regardless of device timezone.
    final day = serviceDate.isUtc ? nowIst(instant: serviceDate) : serviceDate;
    return DateTime.utc(day.year, day.month, day.day)
        .isAfter(DateTime.utc(today.year, today.month, today.day));
  }

  /// Whether current time is past 9:00 PM today (tomorrow's batch is locked for woodfire prep)
  static bool isAfterCutoffToday({DateTime? instant}) =>
      !canModifyTomorrowMeal(instant: instant);

  /// Calculates the next guaranteed delivery date:
  /// - Before 9:00 PM IST: Tomorrow Morning
  /// - After 9:00 PM IST: Next-to-Next Day Morning (Day + 2)
  static DateTime targetDeliveryDate({DateTime? instant}) {
    final now = instant ?? DateTime.now();
    final day = nowIst(instant: now);
    final daysAhead = canModifyTomorrowMeal(instant: now) ? 1 : 2;
    return DateTime(day.year, day.month, day.day + daysAhead);
  }

  static const List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Human-readable target delivery day label
  static String targetDeliveryLabel() {
    final now = DateTime.now();
    final target = targetDeliveryDate(instant: now);
    final tomorrow = nowIst(instant: now).add(const Duration(days: 1));
    final dayStr = _dayNames[target.weekday - 1];
    final monthStr = _monthNames[target.month - 1];

    if (target.day == tomorrow.day && target.month == tomorrow.month) {
      return 'Tomorrow Morning ($dayStr, ${target.day} $monthStr)';
    } else {
      return '$dayStr Morning (${target.day} $monthStr)';
    }
  }

  /// Generates a deterministic 4-character parcel bag token (#SS-04)
  /// Used by security guards and hostel students to identify bags instantly.
  static String generateBagToken(String clusterName, [int seed = 4]) {
    final words =
        clusterName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    String prefix = 'TS';
    if (words.length >= 2) {
      prefix = '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty && words[0].length >= 2) {
      prefix = words[0].substring(0, 2).toUpperCase();
    }
    final numStr = (seed % 99 + 1).toString().padLeft(2, '0');
    return '#$prefix-$numStr';
  }
}
