import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/calendar.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'task_widgets.dart';

const _columnWidth = 272.0;

/// Trello-style board: columns of cards. Cards are dragged within and
/// between columns; each column has "add a card" at its foot and a new
/// column can be added at the end.
class TaskBoard extends StatelessWidget {
  const TaskBoard({
    super.key,
    required this.lists,
    required this.cards,
    required this.onAddCard,
    required this.onMove,
    required this.onToggle,
    required this.onOpen,
    required this.onAddList,
    required this.onRenameList,
    required this.onDeleteList,
  });

  final List<TaskList> lists;

  /// Cards by column id, in order.
  final Map<String, List<Task>> cards;

  final void Function(String listId, String title) onAddCard;

  /// Drop of [taskId] into [listId] above [beforeTaskId] (end when null).
  final void Function(String taskId, String listId, String? beforeTaskId)
  onMove;

  final ValueChanged<Task> onToggle;
  final ValueChanged<Task> onOpen;
  final ValueChanged<String> onAddList;
  final void Function(TaskList list, String name) onRenameList;
  final ValueChanged<TaskList> onDeleteList;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => _BoardScroller(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            for (final list in lists)
              _Column(
                key: ValueKey(list.id),
                list: list,
                cards: cards[list.id] ?? const [],
                board: this,
                // Leaves room for the board's padding and its scrollbar.
                maxHeight: constraints.maxHeight - 40,
              ),
            SizedBox(
              width: _columnWidth,
              child: _InlineAdd(
                label: l.addList,
                hint: l.listName,
                onSubmit: onAddList,
                keepOpen: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scrolls the board sideways with an always-visible scrollbar; each column
/// scrolls its own cards.
class _BoardScroller extends StatefulWidget {
  const _BoardScroller({required this.child});

  final Widget child;

  @override
  State<_BoardScroller> createState() => _BoardScrollerState();
}

class _BoardScrollerState extends State<_BoardScroller> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        child: widget.child,
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    super.key,
    required this.list,
    required this.cards,
    required this.board,
    required this.maxHeight,
  });

  final TaskList list;
  final List<Task> cards;
  final TaskBoard board;
  final double maxHeight;

  Future<void> _rename(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: list.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.rename),
        content: SizedBox(
          width: 280,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l.listName),
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
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) board.onRenameList(list, name);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      width: _columnWidth,
      constraints: BoxConstraints(maxHeight: maxHeight < 160 ? 160 : maxHeight),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: MacColors.of(context).group,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  localNumber(context, cards.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: list.name,
                  icon: const Icon(CupertinoIcons.ellipsis, size: 16),
                  onSelected: (choice) => choice == 'rename'
                      ? _rename(context)
                      : board.onDeleteList(list),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      height: 30,
                      child: Text(l.rename),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      height: 30,
                      child: Text(l.deleteList),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final card in cards)
                    _DropSlot(
                      // Dropping a card onto its own slot would not move it.
                      accepts: (id) => id != card.id,
                      onDrop: (id) => board.onMove(id, list.id, card.id),
                      child: Draggable<String>(
                        data: card.id,
                        feedback: Transform.rotate(
                          angle: 0.04,
                          child: SizedBox(
                            width: _columnWidth - 16,
                            child: _Card(task: card, lifted: true),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _Card(task: card),
                        ),
                        child: _Card(
                          task: card,
                          onToggle: () => board.onToggle(card),
                          onOpen: () => board.onOpen(card),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _DropSlot(
            accepts: (id) => cards.isEmpty || cards.last.id != id,
            onDrop: (id) => board.onMove(id, list.id, null),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _InlineAdd(
                label: l.addCard,
                hint: l.cardTitleHint,
                onSubmit: (title) => board.onAddCard(list.id, title),
                keepOpen: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Drop target that shows a line above its child where the card will land.
class _DropSlot extends StatelessWidget {
  const _DropSlot({
    required this.accepts,
    required this.onDrop,
    required this.child,
  });

  final bool Function(String taskId) accepts;
  final ValueChanged<String> onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => accepts(details.data),
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: candidates.isEmpty ? Colors.transparent : accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

extension TaskLabelColor on TaskLabel {
  Color get color => switch (this) {
    TaskLabel.green => const Color(0xFF4BCE97),
    TaskLabel.yellow => const Color(0xFFE2B203),
    TaskLabel.orange => const Color(0xFFFEA362),
    TaskLabel.red => const Color(0xFFF87168),
    TaskLabel.purple => const Color(0xFF9F8FEF),
    TaskLabel.blue => const Color(0xFF579DFF),
  };
}

class _Card extends StatelessWidget {
  const _Card({
    required this.task,
    this.onToggle,
    this.onOpen,
    this.lifted = false,
  });

  final Task task;
  final VoidCallback? onToggle;
  final VoidCallback? onOpen;

  /// Drawn with a shadow while being dragged.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: MacColors.of(context).control,
      elevation: lifted ? 8 : 0.5,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 4,
            end: 10,
            top: 8,
            bottom: 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              if (task.labels.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final label in TaskLabel.values)
                        if (task.labels.contains(label))
                          Container(
                            width: 38,
                            height: 7,
                            decoration: BoxDecoration(
                              color: label.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  TaskCheck(task: task, size: 16, onChanged: onToggle ?? () {}),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: task.isDone
                                ? TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                          TaskMeta(task: task),
                        ],
                      ),
                    ),
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

/// A quiet "+ label" row that turns into a text field when pressed. Enter
/// submits; Escape or leaving the field closes it. With [keepOpen] the
/// field stays for the next entry, as Trello does for cards.
class _InlineAdd extends StatefulWidget {
  const _InlineAdd({
    required this.label,
    required this.hint,
    required this.onSubmit,
    required this.keepOpen,
  });

  final String label;
  final String hint;
  final ValueChanged<String> onSubmit;
  final bool keepOpen;

  @override
  State<_InlineAdd> createState() => _InlineAddState();
}

class _InlineAddState extends State<_InlineAdd> {
  final _text = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);
  var _open = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _open && mounted) setState(() => _open = false);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _text.clear();
      setState(() => _open = false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit(String value) {
    final text = value.trim();
    if (text.isNotEmpty) widget.onSubmit(text);
    _text.clear();
    if (widget.keepOpen && text.isNotEmpty) {
      _focus.requestFocus();
    } else {
      setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_open) {
      return TextField(
        controller: _text,
        focusNode: _focus,
        autofocus: true,
        onSubmitted: _submit,
        decoration: InputDecoration(hintText: widget.hint),
      );
    }
    return TextButton.icon(
      onPressed: () => setState(() => _open = true),
      style: TextButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
      ),
      icon: const Icon(CupertinoIcons.add, size: 14),
      label: Text(widget.label),
    );
  }
}
