import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/calendar.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'date_picker.dart';

/// Ring color for a task's priority; null for no priority.
Color? priorityColor(int priority, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (priority) {
    3 => Color(dark ? 0xFFFF5A52 : 0xFFD9363E),
    2 => Color(dark ? 0xFFFF9F0A : 0xFFC96A0A),
    1 => Color(dark ? 0xFF0A84FF : 0xFF007AFF),
    _ => null,
  };
}

/// Round checkbox as in Reminders: the ring carries the priority color.
class TaskCheck extends StatelessWidget {
  const TaskCheck({
    super.key,
    required this.task,
    required this.onChanged,
    this.size = 19,
  });

  final Task task;
  final VoidCallback onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color =
        priorityColor(task.priority, theme.brightness) ??
        theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      checked: task.isDone,
      label: task.isDone ? l.markNotDone : l.markDone,
      child: InkWell(
        onTap: onChanged,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.isDone ? color : Colors.transparent,
              border: Border.all(color: color, width: 1.6),
            ),
            child: task.isDone
                ? Icon(
                    CupertinoIcons.checkmark,
                    size: size * 0.62,
                    color: theme.colorScheme.surface,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// One line of small facts under a task title: due day, project, subtask
/// progress, repeat and source markers.
class TaskMeta extends StatelessWidget {
  const TaskMeta({super.key, required this.task, this.projectName});

  final Task task;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final soft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final overdue = !task.isDone && task.dueDay != null && task.dueDay! < today;

    final parts = <InlineSpan>[];
    void add(InlineSpan span) {
      if (parts.isNotEmpty) parts.add(const TextSpan(text: '  ·  '));
      parts.add(span);
    }

    WidgetSpan icon(IconData data) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(data, size: 12, color: soft?.color),
    );

    if (task.dueDay != null) {
      add(
        TextSpan(
          text: dueLabel(context, task.dueDay!),
          style: overdue ? TextStyle(color: theme.colorScheme.error) : null,
        ),
      );
    }
    if (task.repeat != TaskRepeat.none) add(icon(CupertinoIcons.repeat));
    if (projectName != null) add(TextSpan(text: projectName));
    if (task.subtaskCount > 0) {
      add(
        TextSpan(
          text: l.subtaskProgress(
            localNumber(context, task.subtasksDone),
            localNumber(context, task.subtaskCount),
          ),
        ),
      );
    }
    if (task.sourceKind != null) add(icon(CupertinoIcons.link));
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text.rich(
      TextSpan(children: parts),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: soft,
    );
  }
}
