import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Bar across the top of a pane: title at the start, actions at the end,
/// hairline underneath.
class MacToolbar extends StatelessWidget implements PreferredSizeWidget {
  const MacToolbar({
    super.key,
    this.leading,
    this.title,
    this.titleWidget,
    this.actions = const [],
  });

  final Widget? leading;
  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;

  static const height = 50.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height + MediaQuery.paddingOf(context).top,
      padding: EdgeInsetsDirectional.only(
        top: MediaQuery.paddingOf(context).top,
        start: leading == null ? 18 : 8,
        end: 10,
      ),
      decoration: BoxDecoration(
        color: MacColors.of(context).toolbar,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Expanded(
            child:
                titleWidget ??
                Text(
                  title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
          ),
          for (final action in actions) ...[const SizedBox(width: 2), action],
        ],
      ),
    );
  }
}

/// Toolbar icon button with a tooltip and an optional "on" state.
class MacIconButton extends StatelessWidget {
  const MacIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: active
          ? IconButton.styleFrom(
              backgroundColor: MacColors.of(context).selection,
              foregroundColor: theme.colorScheme.primary,
            )
          : null,
      icon: Icon(icon),
    );
  }
}

/// Rounded box that groups settings rows, as in macOS System Settings.
class MacGroup extends StatelessWidget {
  const MacGroup({super.key, this.header, required this.children});

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, bottom: 6),
            child: Text(
              header!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: MacColors.of(context).group,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(indent: 12, endIndent: 12),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One settings row: label at the start, control at the end. A wide
/// [control] may be placed [below] the label instead.
class MacRow extends StatelessWidget {
  const MacRow({super.key, required this.label, this.control, this.below});

  final String label;
  final Widget? control;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              ?control,
            ],
          ),
          ?below,
        ],
      ),
    );
  }
}

/// Pop-up button: shows the current choice with an up/down chevron and
/// opens a menu of the others.
class MacPopupButton<T> extends StatelessWidget {
  const MacPopupButton({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: '',
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final entry in items.entries)
          PopupMenuItem(value: entry.key, height: 30, child: Text(entry.value)),
      ],
      child: Container(
        padding: const EdgeInsetsDirectional.only(
          start: 10,
          end: 6,
          top: 4,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: MacColors.of(context).control,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Text(items[value] ?? ''),
            Icon(
              CupertinoIcons.chevron_up_chevron_down,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded search field with a magnifier, as in macOS toolbars.
class MacSearchField extends StatelessWidget {
  const MacSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          CupertinoIcons.search,
          size: 15,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 32),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}

/// Centered message for a pane that has nothing to show yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(title, style: theme.textTheme.titleLarge),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 8), action!],
            ],
          ),
        ),
      ),
    );
  }
}
