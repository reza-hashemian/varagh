import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/mac_widgets.dart';
import '../data/library.dart';
import '../draw/mark_painter.dart';
import '../l10n/app_localizations.dart';
import 'translator.dart';

/// Shows [text] with its translation. The language translated into starts
/// as the app's own and can be changed there; the choice is remembered.
Future<void> showTranslation(BuildContext context, String text) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _TranslationDialog(library: AppScope.read(context).library, text: text),
  );
}

class _TranslationDialog extends StatefulWidget {
  const _TranslationDialog({required this.library, required this.text});

  final Library library;
  final String text;

  @override
  State<_TranslationDialog> createState() => _TranslationDialogState();
}

class _TranslationDialogState extends State<_TranslationDialog> {
  final _translator = Translator();
  String? _to;
  String? _result;
  var _failed = false;

  /// Counts requests, so a late answer to an earlier one is ignored.
  var _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_to != null) return;
    final saved = widget.library.setting('translate.target');
    final own = Localizations.localeOf(context).languageCode;
    _to = translationLanguages.containsKey(saved)
        ? saved
        : translationLanguages.containsKey(own)
        ? own
        : 'en';
    _translate();
  }

  @override
  void dispose() {
    _translator.close();
    super.dispose();
  }

  Future<void> _translate() async {
    final request = ++_request;
    setState(() {
      _result = null;
      _failed = false;
    });
    String? result;
    try {
      result = await _translator.translate(widget.text, to: _to!);
    } on Exception {
      result = null;
    }
    if (!mounted || request != _request) return;
    setState(() {
      _result = result;
      _failed = result == null;
    });
  }

  void _setTarget(String to) {
    if (to == _to) return;
    _to = to;
    widget.library.setSetting('translate.target', to);
    _translate();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final result = _result;

    final Widget body;
    if (result != null) {
      body = SelectableText(
        result,
        textDirection: startsRtl(result)
            ? TextDirection.rtl
            : TextDirection.ltr,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
      );
    } else if (_failed) {
      body = Column(
        spacing: 8,
        children: [
          Text(l.translateFailed, textAlign: TextAlign.center, style: muted),
          TextButton(onPressed: _translate, child: Text(l.retry)),
        ],
      );
    } else {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return Dialog(
      // Narrower margins than a dialog's usual, to leave a phone's width
      // to the text.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Text(
                widget.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textDirection: startsRtl(widget.text)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                style: muted,
              ),
              const Divider(height: 1),
              Flexible(child: SingleChildScrollView(child: body)),
              // Wraps onto two lines where a narrow phone can't fit one.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 8,
                children: [
                  MacPopupButton<String>(
                    value: _to!,
                    items: translationLanguages,
                    onChanged: _setTarget,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      MacIconButton(
                        icon: CupertinoIcons.doc_on_doc,
                        tooltip: l.copy,
                        onPressed: result == null
                            ? null
                            : () => Clipboard.setData(
                                ClipboardData(text: result),
                              ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l.done),
                      ),
                    ],
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
