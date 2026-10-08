import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Calendar days are stored as whole days since 1970-01-01, free of time
/// zones: a task due on a date is due on that date wherever it is read.
int dayOf(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

DateTime dateOfDay(int day) {
  final utc = DateTime.fromMillisecondsSinceEpoch(
    day * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(utc.year, utc.month, utc.day);
}

int get today => dayOf(DateTime.now());

/// Gregorian to Solar Hijri (Jalali) as (year, month, day).
(int, int, int) toJalali(DateTime date) {
  var gy = date.year;
  final gm = date.month, gd = date.day;
  const daysBefore = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  int jy;
  if (gy > 1600) {
    jy = 979;
    gy -= 1600;
  } else {
    jy = 0;
    gy -= 621;
  }
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days =
      365 * gy +
      (gy2 + 3) ~/ 4 -
      (gy2 + 99) ~/ 100 +
      (gy2 + 399) ~/ 400 -
      80 +
      gd +
      daysBefore[gm - 1];
  jy += 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return (jy, jm, jd);
}

/// Solar Hijri (Jalali) to Gregorian.
DateTime fromJalali(int jy, int jm, int jd) {
  jy += 1595;
  var days =
      -355668 +
      365 * jy +
      (jy ~/ 33) * 8 +
      ((jy % 33) + 3) ~/ 4 +
      jd +
      (jm < 7 ? (jm - 1) * 31 : (jm - 7) * 30 + 186);
  var gy = 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    days--;
    gy += 100 * (days ~/ 36524);
    days %= 36524;
    if (days >= 365) days++;
  }
  gy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  return DateTime(gy, 1, 1 + days);
}

/// A month grid in either the Solar Hijri or the Gregorian calendar, so the
/// date picker can show whichever the current language uses.
class MonthCalendar {
  const MonthCalendar({required this.jalali});

  factory MonthCalendar.of(BuildContext context) => MonthCalendar(
    jalali: Localizations.localeOf(context).languageCode == 'fa',
  );

  final bool jalali;

  static const _jalaliMonths = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', //
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  /// Weekday the grid starts on, as a [DateTime.weekday] value.
  int get firstWeekday => jalali ? DateTime.saturday : DateTime.monday;

  (int, int, int) parts(DateTime date) =>
      jalali ? toJalali(date) : (date.year, date.month, date.day);

  DateTime date(int year, int month, int day) =>
      jalali ? fromJalali(year, month, day) : DateTime(year, month, day);

  int monthLength(int year, int month) {
    final (nextYear, nextMonth) = month == 12
        ? (year + 1, 1)
        : (year, month + 1);
    return dayOf(date(nextYear, nextMonth, 1)) - dayOf(date(year, month, 1));
  }

  String monthName(int month, String languageCode) => jalali
      ? _jalaliMonths[month - 1]
      : DateFormat.MMMM(languageCode).format(DateTime(2000, month));
}

/// Whole number in the digits of the current language (۱۴۲ in Persian).
String localNumber(BuildContext context, int value) => NumberFormat(
  '#',
  Localizations.localeOf(context).languageCode,
).format(value);

String localPercent(BuildContext context, double fraction) =>
    NumberFormat.percentPattern(Localizations.localeOf(context).languageCode)
        .format(fraction);

/// Short date in the calendar of the current language: Persian shows the
/// Solar Hijri date, English the Gregorian one. The year is left out when it
/// is the current one and [alwaysYear] is false.
String localDate(
  BuildContext context,
  DateTime date, {
  bool alwaysYear = true,
}) {
  final code = Localizations.localeOf(context).languageCode;
  final calendar = MonthCalendar.of(context);
  final (year, month, day) = calendar.parts(date);
  final showYear = alwaysYear || year != calendar.parts(DateTime.now()).$1;
  if (!calendar.jalali) {
    return (showYear ? DateFormat.yMMMd(code) : DateFormat.MMMd(code)).format(
      date,
    );
  }
  final text =
      '${localNumber(context, day)} ${calendar.monthName(month, code)}';
  return showYear ? '$text ${localNumber(context, year)}' : text;
}
