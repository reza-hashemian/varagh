import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/mac_widgets.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Wraps the selection in [before] and [after], or unwraps it if it already
/// is. With nothing selected, inserts the pair around [placeholder] and
/// selects the placeholder so typing replaces it.
TextEditingValue wrapSelection(
  TextEditingValue value,
  String before,
  String after, {
  String placeholder = '',
}) {
  final text = value.text;
  final sel = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: text.length);
  final start = sel.start, end = sel.end;
  final selected = text.substring(start, end);

  final wrappedOutside =
      start >= before.length &&
      end + after.length <= text.length &&
      text.substring(start - before.length, start) == before &&
      text.substring(end, end + after.length) == after;
  if (wrappedOutside) {
    return TextEditingValue(
      text:
          text.substring(0, start - before.length) +
          selected +
          text.substring(end + after.length),
      selection: TextSelection(
        baseOffset: start - before.length,
        extentOffset: end - before.length,
      ),
    );
  }

  final inner = selected.isEmpty ? placeholder : selected;
  return TextEditingValue(
    text:
        text.substring(0, start) + before + inner + after + text.substring(end),
    selection: TextSelection(
      baseOffset: start + before.length,
      extentOffset: start + before.length + inner.length,
    ),
  );
}

/// Puts a Markdown marker at the start of every selected line, or removes
/// it if every line already has it. [prefix] gets the 1-based line number;
/// the list and heading markers it replaces are stripped first, so a
/// bulleted list can be switched to a numbered one.
TextEditingValue prefixLines(
  TextEditingValue value,
  String Function(int number) prefix,
) {
  final text = value.text;
  final sel = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: text.length);
  final lineStart = sel.start == 0
      ? 0
      : text.lastIndexOf('\n', sel.start - 1) + 1;
  var lineEnd = text.indexOf('\n', sel.end);
  if (lineEnd < 0) lineEnd = text.length;

  final lines = text.substring(lineStart, lineEnd).split('\n');
  final marker = RegExp(r'^(#{1,6} |> |- \[[ x]\] |[-*+] |\d+\. )');
  final allPrefixed = [
    for (var i = 0; i < lines.length; i++) lines[i].startsWith(prefix(i + 1)),
  ].every((v) => v);
  final changed = [
    for (var i = 0; i < lines.length; i++)
      allPrefixed
          ? lines[i].substring(prefix(i + 1).length)
          : prefix(i + 1) + lines[i].replaceFirst(marker, ''),
  ].join('\n');

  return TextEditingValue(
    text: text.substring(0, lineStart) + changed + text.substring(lineEnd),
    selection: TextSelection.collapsed(offset: lineStart + changed.length),
  );
}

/// Inserts [block] on its own lines at the cursor.
TextEditingValue insertBlock(TextEditingValue value, String block) {
  final text = value.text;
  final at = value.selection.isValid ? value.selection.end : text.length;
  final lead = at == 0 || text[at - 1] == '\n' ? '' : '\n';
  final inserted = '$lead\n$block\n\n';
  return TextEditingValue(
    text: text.substring(0, at) + inserted + text.substring(at),
    selection: TextSelection.collapsed(offset: at + inserted.length),
  );
}

/// Row of formatting buttons that write Markdown into [controller].
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Called after a button changed the text.
  final VoidCallback onChanged;

  void _apply(TextEditingValue Function(TextEditingValue) edit) {
    controller.value = edit(controller.value);
    focusNode.requestFocus();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget button(
      IconData icon,
      String tip,
      TextEditingValue Function(TextEditingValue) edit,
    ) => MacIconButton(icon: icon, tooltip: tip, onPressed: () => _apply(edit));
    Widget gap() => Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: theme.colorScheme.outlineVariant,
    );

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: MacColors.of(context).toolbar,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      // Markdown syntax reads left to right whatever the interface language.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              PopupMenuButton<int>(
                tooltip: l.mdHeading,
                icon: const Icon(CupertinoIcons.textformat_size),
                onSelected: (level) =>
                    _apply((v) => prefixLines(v, (_) => '${'#' * level} ')),
                itemBuilder: (context) => [
                  for (var level = 1; level <= 3; level++)
                    PopupMenuItem(
                      value: level,
                      height: 32,
                      child: Text(
                        '${l.mdHeading} ${'#' * level}',
                        style: TextStyle(
                          fontSize: 19.0 - level * 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              gap(),
              button(
                CupertinoIcons.bold,
                l.mdBold,
                (v) => wrapSelection(v, '**', '**', placeholder: l.mdBold),
              ),
              button(
                CupertinoIcons.italic,
                l.mdItalic,
                (v) => wrapSelection(v, '*', '*', placeholder: l.mdItalic),
              ),
              button(
                CupertinoIcons.strikethrough,
                l.mdStrike,
                (v) => wrapSelection(v, '~~', '~~', placeholder: l.mdStrike),
              ),
              button(
                CupertinoIcons.chevron_left_slash_chevron_right,
                l.mdCode,
                (v) =>
                    v.selection.isValid &&
                        v.selection.textInside(v.text).contains('\n')
                    ? wrapSelection(v, '```\n', '\n```')
                    : wrapSelection(v, '`', '`', placeholder: l.mdCode),
              ),
              gap(),
              button(
                CupertinoIcons.list_bullet,
                l.mdBullets,
                (v) => prefixLines(v, (_) => '- '),
              ),
              button(
                CupertinoIcons.list_number,
                l.mdNumbers,
                (v) => prefixLines(v, (n) => '$n. '),
              ),
              button(
                CupertinoIcons.checkmark_square,
                l.mdChecklist,
                (v) => prefixLines(v, (_) => '- [ ] '),
              ),
              button(
                CupertinoIcons.text_quote,
                l.mdQuote,
                (v) => prefixLines(v, (_) => '> '),
              ),
              gap(),
              button(
                CupertinoIcons.link,
                l.mdLink,
                (v) =>
                    wrapSelection(v, '[', '](https://)', placeholder: l.mdLink),
              ),
              button(
                CupertinoIcons.table,
                l.mdTable,
                (v) => insertBlock(v, '|  |  |\n| --- | --- |\n|  |  |'),
              ),
              button(
                CupertinoIcons.minus,
                l.mdDivider,
                (v) => insertBlock(v, '---'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
