import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/core/app_state.dart';

void main() {
  test('Gregorian dates convert to Solar Hijri', () {
    expect(toJalali(DateTime(2026, 10, 7)), (1405, 7, 15));
    expect(toJalali(DateTime(2025, 3, 21)), (1404, 1, 1));
    expect(toJalali(DateTime(2025, 3, 20)), (1403, 12, 30));
    expect(toJalali(DateTime(2024, 3, 19)), (1402, 12, 29));
    expect(toJalali(DateTime(2000, 1, 1)), (1378, 10, 11));
  });

  test('Solar Hijri converts back to the same day for 60 years', () {
    for (var day = dayOf(DateTime(1990)); day < dayOf(DateTime(2050)); day++) {
      final date = dateOfDay(day);
      final (y, m, d) = toJalali(date);
      expect(fromJalali(y, m, d), date);
    }
  });

  test('month lengths follow each calendar', () {
    const jalali = MonthCalendar(jalali: true);
    expect(jalali.monthLength(1405, 1), 31);
    expect(jalali.monthLength(1405, 7), 30);
    expect(jalali.monthLength(1403, 12), 30); // leap year
    expect(jalali.monthLength(1404, 12), 29);
    const gregorian = MonthCalendar(jalali: false);
    expect(gregorian.monthLength(2024, 2), 29);
    expect(gregorian.monthLength(2026, 12), 31);
  });

  test('day numbers round-trip without drifting across time zones', () {
    expect(
      dateOfDay(dayOf(DateTime(2026, 10, 7, 23, 59))),
      DateTime(2026, 10, 7),
    );
    expect(dayOf(DateTime(2026, 10, 8)) - dayOf(DateTime(2026, 10, 7)), 1);
  });
}
