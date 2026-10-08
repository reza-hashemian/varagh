import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/mac_widgets.dart';
import '../core/theme.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'board.dart';
import 'task_dialog.dart';
import 'task_widgets.dart';

const _twoPane = 640.0;
const _projectPrefix = 'p:';

/// Tasks as smart lists (today, scheduled, all, completed) and projects.
/// A project opens as a Trello-style board and can be switched to a list.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final AppState _state = AppScope.read(context);
  late final Library _library = _state.library;
  final _newTask = TextEditingController();
  final _newTaskFocus = FocusNode();

  /// 'today', 'scheduled', 'all', 'done', or 'p:' followed by a project id.
  late String _filter = _library.setting('tasks.filter') ?? 'today';

  /// How a project is shown; smart lists are always lists.
  late bool _board = _library.setting('tasks.view') != 'list';

  @override
  void dispose() {
    _newTask.dispose();
    _newTaskFocus.dispose();
    super.dispose();
  }

  String? get _projectId => _filter.startsWith(_projectPrefix)
      ? _filter.substring(_projectPrefix.length)
      : null;

  void _setFilter(String filter) {
    setState(() => _filter = filter);
    _library.setSetting('tasks.filter', filter);
  }

  void _setBoard(bool board) {
    setState(() => _board = board);
    _library.setSetting('tasks.view', board ? 'board' : 'list');
  }

  void _addTask(String text) {
    final title = text.trim();
    if (title.isEmpty) return;
    _library.addTask(
      title: title,
      projectId: _projectId,
      dueDay: _filter == 'today' || _filter == 'scheduled' ? today : null,
    );
    _newTask.clear();
    _newTaskFocus.requestFocus();
    _state.refresh();
  }

  void _toggle(Task task) {
    _library.setTaskStatus(
      task.id,
      task.isDone ? TaskStatus.todo : TaskStatus.done,
      today: today,
    );
    _state.refresh();
  }

  Future<String?> _askName(String title, {String initial = ''}) {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 280,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l.projectName),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(initial.isEmpty ? l.create : l.save),
          ),
        ],
      ),
    );
  }

  Future<void> _newProject() async {
    final l = AppLocalizations.of(context);
    final name = await _askName(l.newProject);
    if (name == null || name.isEmpty) return;
    final project = _library.addProject(
      name,
      listNames: [l.statusTodo, l.statusDoing, l.statusDone],
    );
    _setFilter('$_projectPrefix${project.id}');
    _state.refresh();
  }

  Future<void> _renameProject(Project project) async {
    final l = AppLocalizations.of(context);
    final name = await _askName(l.rename, initial: project.name);
    if (name == null || name.isEmpty) return;
    _library.renameProject(project.id, name);
    _state.refresh();
  }

  Future<void> _deleteProject(Project project) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteProject),
        content: Text(l.deleteProjectBody(project.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _library.removeProject(project.id);
    _setFilter('all');
    _state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Subscribes to refreshes after any task change.
    AppScope.of(context);

    final projects = _library.projects();
    final project = projects.where((p) => p.id == _projectId).firstOrNull;
    // A project filter whose project was deleted elsewhere falls back.
    final filter = _projectId != null && project == null ? 'all' : _filter;
    final names = <String, String>{
      'today': l.today,
      'scheduled': l.scheduled,
      'all': l.allTasks,
      'done': l.completed,
      for (final p in projects) '$_projectPrefix${p.id}': p.name,
    };
    final projectNames = {for (final p in projects) p.id: p.name};

    if (project != null) {
      _library.ensureLists(project.id, [
        l.statusTodo,
        l.statusDoing,
        l.statusDone,
      ]);
    }

    final all = _library.tasks();
    bool inScope(Task t) => project == null || t.projectId == project.id;
    final open = all.where((t) => !t.isDone && inScope(t));
    final shown = switch (filter) {
      'today' => open.where((t) => t.dueDay != null && t.dueDay! <= today),
      'scheduled' => open.where((t) => t.dueDay != null),
      'done' => all.where((t) => t.isDone),
      _ => open,
    }.toList();

    Widget row(Task task) => _TaskRow(
      task: task,
      // Inside a project its name would repeat on every row.
      projectName: project == null ? projectNames[task.projectId] : null,
      onToggle: () => _toggle(task),
      onOpen: () => showTaskDialog(context, task.id),
    );

    final Widget content;
    if (_board && project != null) {
      content = TaskBoard(
        lists: _library.lists(project.id),
        cards: _library.board(project.id),
        onAddCard: (listId, title) {
          _library.addTask(title: title, projectId: project.id, listId: listId);
          _state.refresh();
        },
        onMove: (taskId, listId, beforeTaskId) {
          _library.moveTask(taskId, listId: listId, beforeTaskId: beforeTaskId);
          _state.refresh();
        },
        onToggle: _toggle,
        onOpen: (task) => showTaskDialog(context, task.id),
        onAddList: (name) {
          _library.addList(project.id, name);
          _state.refresh();
        },
        onRenameList: (list, name) {
          _library.renameList(list.id, name);
          _state.refresh();
        },
        onDeleteList: (list) {
          _library.removeList(list.id);
          _state.refresh();
        },
      );
    } else if (shown.isEmpty) {
      content = switch (filter) {
        'today' => EmptyState(
          icon: CupertinoIcons.sun_max,
          title: l.nothingTodayTitle,
          body: l.nothingTodayBody,
        ),
        'done' => EmptyState(
          icon: CupertinoIcons.checkmark_circle,
          title: l.noTasksTitle,
          body: l.noCompletedBody,
        ),
        _ => EmptyState(
          icon: CupertinoIcons.checkmark_circle,
          title: l.noTasksTitle,
          body: l.noTasksBody,
        ),
      };
    } else {
      content = ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: shown.length,
        separatorBuilder: (_, _) => const Divider(indent: 38),
        itemBuilder: (context, i) => row(shown[i]),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= _twoPane;
        final main = Scaffold(
          appBar: MacToolbar(
            title: twoPane ? names[filter] : null,
            titleWidget: twoPane
                ? null
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: MacPopupButton<String>(
                      value: filter,
                      items: names,
                      onChanged: _setFilter,
                    ),
                  ),
            actions: [
              if (project != null)
                PopupMenuButton<String>(
                  tooltip: project.name,
                  icon: const Icon(CupertinoIcons.ellipsis_circle),
                  onSelected: (choice) => choice == 'rename'
                      ? _renameProject(project)
                      : _deleteProject(project),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      height: 30,
                      child: Text(l.rename),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      height: 30,
                      child: Text(l.deleteProject),
                    ),
                  ],
                ),
              if (!twoPane)
                MacIconButton(
                  icon: CupertinoIcons.folder_badge_plus,
                  tooltip: l.newProject,
                  onPressed: _newProject,
                ),
              if (project != null) ...[
                MacIconButton(
                  icon: CupertinoIcons.list_bullet,
                  tooltip: l.listView,
                  active: !_board,
                  onPressed: () => _setBoard(false),
                ),
                MacIconButton(
                  icon: CupertinoIcons.rectangle_split_3x1,
                  tooltip: l.boardView,
                  active: _board,
                  onPressed: () => _setBoard(true),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              if (filter != 'done' && !(_board && project != null))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _newTask,
                    focusNode: _newTaskFocus,
                    onSubmitted: _addTask,
                    decoration: InputDecoration(
                      hintText: l.newTaskHint,
                      prefixIcon: Icon(
                        CupertinoIcons.add,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32),
                    ),
                  ),
                ),
              Expanded(child: content),
            ],
          ),
        );
        if (!twoPane) return main;

        Widget item(String key, IconData icon, {int? count}) => _FilterItem(
          icon: icon,
          label: names[key]!,
          count: count,
          selected: filter == key,
          onTap: () => _setFilter(key),
        );
        final dueNow = open.where(
          (t) => t.dueDay != null && t.dueDay! <= today,
        );

        return Row(
          children: [
            SizedBox(
              width: 210,
              child: Scaffold(
                backgroundColor: theme.colorScheme.surfaceContainerLowest,
                appBar: MacToolbar(title: l.tasks),
                body: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    item(
                      'today',
                      CupertinoIcons.sun_max,
                      count: project == null
                          ? dueNow.length
                          : _library.dueTaskCount(today),
                    ),
                    item('scheduled', CupertinoIcons.calendar),
                    item('all', CupertinoIcons.tray),
                    item('done', CupertinoIcons.checkmark_circle),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 10,
                        top: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.projects,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          MacIconButton(
                            icon: CupertinoIcons.add,
                            tooltip: l.newProject,
                            onPressed: _newProject,
                          ),
                        ],
                      ),
                    ),
                    for (final p in projects)
                      item('$_projectPrefix${p.id}', CupertinoIcons.folder),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: main),
          ],
        );
      },
    );
  }
}

class _FilterItem extends StatelessWidget {
  const _FilterItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? MacColors.of(context).selection : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              spacing: 8,
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count != null && count! > 0)
                  Text(
                    localNumber(context, count!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onOpen,
    this.projectName,
  });

  final Task task;
  final String? projectName;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            TaskCheck(task: task, onChanged: onToggle),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: task.isDone
                          ? TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
                            )
                          : null,
                    ),
                    TaskMeta(task: task, projectName: projectName),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
