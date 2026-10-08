import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/calendar.dart';
import '../core/mac_widgets.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Result of the due date picker. [day] is null when "no date" was chosen.
class DueChoice {
  const DueChoice(this.day);

  final int? day;
}

/// "Today", "Tomorrow" or a short date, for showing a task's due day.
String dueLabel(BuildContext context, int day) {
  final l = AppLocalizations.of(context);
  return switch (day - today) {
    0 => l.today,
    1 => l.tomorrow,
    -1 => l.yesterday,
    _ => localDate(context, dateOfDay(day), alwaysYear: false),
  };
}

/// Month-grid date picker in the calendar of the current language (Solar
/// Hijri for Persian). Returns null if dismissed without choosing.
Future<DueChoice?> showDueDatePicker(BuildContext context, {int? initialDay}) {
  return showDialog<DueChoice>(
    context: context,
    builder: (context) => _DueDateDialog(initialDay: initialDay),
  );
}

class _DueDateDialog extends StatefulWidget {
  const _DueDateDialog({this.initialDay});

  final int? initialDay;

  @override
  State<_DueDateDialog> createState() => _DueDateDialogState();
}

class _DueDateDialogState extends State<_DueDateDialog> {
  late MonthCalendar _calendar;
  int? _year, _month;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calendar = MonthCalendar.of(context);
    if (_year == null) {
      final (year, month, _) = _calendar.parts(
        dateOfDay(widget.initialDay ?? today),
      );
      _year = year;
      _month = month;
    }
  }

  void _shift(int months) {
    var month = _month! + months;
    var year = _year!;
    while (month < 1) {
      month += 12;
      year--;
    }
    while (month > 12) {
      month -= 12;
      year++;
    }
    setState(() {
      _year = year;
      _month = month;
    });
  }

  void _choose(int? day) => Navigator.pop(context, DueChoice(day));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final code = Localizations.localeOf(context).languageCode;
    final year = _year!, month = _month!;
    final first = _calendar.date(year, month, 1);
    final firstDay = dayOf(first);
    final length = _calendar.monthLength(year, month);
    final lead = (first.weekday - _calendar.firstWeekday + 7) % 7;
    final soft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Weekday initials for the header row, starting on the calendar's first
    // weekday. 2024-01-01 was a Monday.
    final weekdayNames = MaterialLocalizations.of(context).narrowWeekdays;
    String weekdayInitial(int column) {
      final weekday = (_calendar.firstWeekday - 1 + column) % 7 + 1;
      // narrowWeekdays starts on Sunday.
      return weekdayNames[weekday % 7];
    }

    return Dialog(
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Row(
                children: [
                  MacIconButton(
                    icon: CupertinoIcons.chevron_back,
                    tooltip: l.previousMonth,
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Text(
                      '${_calendar.monthName(month, code)} '
                      '${localNumber(context, year)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  MacIconButton(
                    icon: CupertinoIcons.chevron_forward,
                    tooltip: l.nextMonth,
                    onPressed: () => _shift(1),
                  ),
                ],
              ),
              Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: Center(
                        child: Text(weekdayInitial(column), style: soft),
                      ),
                    ),
                ],
              ),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < lead; i++) const SizedBox(),
                  for (var d = 1; d <= length; d++)
                    _DayCell(
                      label: localNumber(context, d),
                      selected: firstDay + d - 1 == widget.initialDay,
                      isToday: firstDay + d - 1 == today,
                      onTap: () => _choose(firstDay + d - 1),
                    ),
                ],
              ),
              const Divider(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _choose(today),
                    child: Text(l.today),
                  ),
                  OutlinedButton(
                    onPressed: () => _choose(today + 1),
                    child: Text(l.tomorrow),
                  ),
                  OutlinedButton(
                    onPressed: () => _choose(today + 7),
                    child: Text(l.nextWeek),
                  ),
                  TextButton(
                    onPressed: () => _choose(null),
                    child: Text(l.noDate),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected
            ? scheme.primary
            : isToday
            ? MacColors.of(context).selection
            : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selected ? scheme.onPrimary : null,
                fontWeight: isToday || selected ? FontWeight.w700 : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
