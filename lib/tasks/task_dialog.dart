import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/mac_widgets.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../home_shell.dart';
import '../l10n/app_localizations.dart';
import 'board.dart';
import 'date_picker.dart';
import 'task_widgets.dart';

/// Opens the editor for one task. Every change is saved as it is made.
Future<void> showTaskDialog(BuildContext context, String taskId) {
  return showDialog<void>(
    context: context,
    builder: (context) => _TaskDialog(taskId: taskId),
  );
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({required this.taskId});

  final String taskId;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final AppState _state = AppScope.read(context);
  late final Library _library = _state.library;
  late final TextEditingController _title;
  late final TextEditingController _notes;
  final _subtask = TextEditingController();
  final _subtaskFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final task = _library.task(widget.taskId);
    _title = TextEditingController(text: task?.title);
    _notes = TextEditingController(text: task?.notes);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _subtask.dispose();
    _subtaskFocus.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    _state.refresh();
  }

  void _saveText() {
    final task = _library.task(widget.taskId);
    if (task == null) return;
    final title = _title.text.trim();
    final notes = _notes.text.trim();
    if ((title.isEmpty || title == task.title) && notes == task.notes) return;
    _library.updateTask(
      task.id,
      title: title.isEmpty ? null : title,
      notes: notes,
    );
    _state.refresh();
  }

  void _close() {
    _saveText();
    Navigator.pop(context);
  }

  Future<void> _pickDue(Task task) async {
    final choice = await showDueDatePicker(context, initialDay: task.dueDay);
    if (choice == null) return;
    _library.setTaskDue(task.id, choice.day);
    if (choice.day == null && task.repeat != TaskRepeat.none) {
      _library.updateTask(task.id, repeat: TaskRepeat.none);
    }
    _changed();
  }

  void _addSubtask(String text) {
    final title = text.trim();
    if (title.isEmpty) return;
    _library.addTask(title: title, parentId: widget.taskId);
    _subtask.clear();
    _subtaskFocus.requestFocus();
    _changed();
  }

  void _openSource(Task task) {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (task.sourceKind == 'note' && _library.note(task.sourceId!) != null) {
      _saveText();
      navigator.pop();
      _state.showNote(task.sourceId!);
      return;
    }
    if (task.sourceKind == 'annotation') {
      final annotation = _library.annotation(task.sourceId!);
      final book = annotation == null ? null : _library.book(annotation.bookId);
      if (book != null) {
        _saveText();
        navigator.pop();
        openBook(navigator.context, book, annotationId: annotation!.id);
        return;
      }
    }
    messenger.showSnackBar(SnackBar(content: Text(l.sourceGone)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final task = _library.task(widget.taskId);
    if (task == null) return const SizedBox.shrink();
    final projects = _library.projects();
    final subtasks = _library.subtasks(task.id);
    final lists = task.projectId == null
        ? const <TaskList>[]
        : _library.lists(task.projectId!);
    final labelNames = {
      TaskLabel.green: l.labelGreen,
      TaskLabel.yellow: l.labelYellow,
      TaskLabel.orange: l.labelOrange,
      TaskLabel.red: l.labelRed,
      TaskLabel.purple: l.labelPurple,
      TaskLabel.blue: l.labelBlue,
    };
    final soft = TextStyle(color: theme.colorScheme.onSurfaceVariant);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Dismissing by tapping outside or pressing Escape keeps the text.
        if (!didPop) _close();
      },
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Row(
                  spacing: 10,
                  children: [
                    TaskCheck(
                      task: task,
                      onChanged: () {
                        _library.setTaskStatus(
                          task.id,
                          task.isDone ? TaskStatus.todo : TaskStatus.done,
                          today: today,
                        );
                        _changed();
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _title,
                        style: theme.textTheme.titleMedium,
                        decoration: InputDecoration(hintText: l.taskTitleHint),
                        onSubmitted: (_) => _saveText(),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(hintText: l.taskNotesHint),
                ),
                MacGroup(
                  children: [
                    MacRow(
                      label: l.dueDate,
                      control: OutlinedButton(
                        onPressed: () => _pickDue(task),
                        child: Text(
                          task.dueDay == null
                              ? l.noDate
                              : dueLabel(context, task.dueDay!),
                        ),
                      ),
                    ),
                    MacRow(
                      label: l.repeat,
                      control: MacPopupButton<TaskRepeat>(
                        value: task.repeat,
                        items: {
                          TaskRepeat.none: l.repeatNone,
                          TaskRepeat.daily: l.repeatDaily,
                          TaskRepeat.weekly: l.repeatWeekly,
                          TaskRepeat.monthly: l.repeatMonthly,
                        },
                        onChanged: (repeat) {
                          if (repeat != TaskRepeat.none &&
                              task.dueDay == null) {
                            _library.setTaskDue(task.id, today);
                          }
                          _library.updateTask(task.id, repeat: repeat);
                          _changed();
                        },
                      ),
                    ),
                    MacRow(
                      label: l.priority,
                      control: MacPopupButton<int>(
                        value: task.priority,
                        items: {
                          0: l.priorityNone,
                          1: l.priorityLow,
                          2: l.priorityMedium,
                          3: l.priorityHigh,
                        },
                        onChanged: (priority) {
                          _library.updateTask(task.id, priority: priority);
                          _changed();
                        },
                      ),
                    ),
                    MacRow(
                      label: l.project,
                      control: MacPopupButton<String>(
                        value: task.projectId ?? '',
                        items: {
                          '': l.noProject,
                          for (final project in projects)
                            project.id: project.name,
                        },
                        onChanged: (id) {
                          _library.setTaskProject(
                            task.id,
                            id.isEmpty ? null : id,
                          );
                          _changed();
                        },
                      ),
                    ),
                    if (lists.isNotEmpty && task.listId != null)
                      MacRow(
                        label: l.list,
                        control: MacPopupButton<String>(
                          value: task.listId!,
                          items: {for (final list in lists) list.id: list.name},
                          onChanged: (id) {
                            if (id == task.listId) return;
                            _library.moveTask(task.id, listId: id);
                            _changed();
                          },
                        ),
                      ),
                    MacRow(
                      label: l.labels,
                      control: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          for (final label in TaskLabel.values)
                            Tooltip(
                              message: labelNames[label],
                              child: Semantics(
                                button: true,
                                selected: task.labels.contains(label),
                                label: labelNames[label],
                                child: InkWell(
                                  onTap: () {
                                    final labels = {...task.labels};
                                    if (!labels.remove(label)) {
                                      labels.add(label);
                                    }
                                    _library.setTaskLabels(task.id, labels);
                                    _changed();
                                  },
                                  borderRadius: BorderRadius.circular(5),
                                  child: Container(
                                    width: 26,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: label.color,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: task.labels.contains(label)
                                        ? const Icon(
                                            CupertinoIcons.checkmark,
                                            size: 12,
                                            color: Colors.black87,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  l.subtasks,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final subtask in subtasks)
                  Row(
                    spacing: 8,
                    children: [
                      TaskCheck(
                        task: subtask,
                        size: 16,
                        onChanged: () {
                          _library.setTaskStatus(
                            subtask.id,
                            subtask.isDone ? TaskStatus.todo : TaskStatus.done,
                            today: today,
                          );
                          _changed();
                        },
                      ),
                      Expanded(
                        child: Text(
                          subtask.title,
                          style: subtask.isDone
                              ? soft.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                      ),
                      MacIconButton(
                        icon: CupertinoIcons.xmark,
                        tooltip: l.delete,
                        onPressed: () {
                          _library.removeTask(subtask.id);
                          _changed();
                        },
                      ),
                    ],
                  ),
                TextField(
                  controller: _subtask,
                  focusNode: _subtaskFocus,
                  onSubmitted: _addSubtask,
                  decoration: InputDecoration(hintText: l.addSubtask),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        _library.removeTask(task.id);
                        _state.refresh();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      child: Text(l.deleteTask),
                    ),
                    if (task.sourceKind != null)
                      TextButton(
                        onPressed: () => _openSource(task),
                        child: Text(l.openSource),
                      ),
                    const Spacer(),
                    FilledButton(onPressed: _close, child: Text(l.done)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
