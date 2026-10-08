import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'page_tint.dart';

/// Page color picker: a popover under the toolbar on wide windows, a bottom
/// sheet on narrow ones. [onChanged] fires on every change so the page
/// behind it updates live.
Future<void> showTintSheet(
  BuildContext context, {
  required PageTint initial,
  required ValueChanged<PageTint> onChanged,
}) {
  final panel = _TintSheet(initial: initial, onChanged: onChanged);
  // The barrier stays clear so the effect of each choice can be judged.
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Dialog(
        alignment: AlignmentDirectional.topEnd,
        insetPadding: const EdgeInsets.only(top: 58, left: 12, right: 12),
        child: SizedBox(
          width: 380,
          child: Padding(padding: const EdgeInsets.only(top: 18), child: panel),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    barrierColor: Colors.transparent,
    builder: (context) => panel,
  );
}

class _TintSheet extends StatefulWidget {
  const _TintSheet({required this.initial, required this.onChanged});

  final PageTint initial;
  final ValueChanged<PageTint> onChanged;

  @override
  State<_TintSheet> createState() => _TintSheetState();
}

class _TintSheetState extends State<_TintSheet> {
  late PageTint _tint = widget.initial;

  void _set(PageTint tint) {
    setState(() => _tint = tint);
    widget.onChanged(tint);
  }

  String _name(AppLocalizations l, PagePaper paper) => switch (paper) {
    PagePaper.original => l.paperOriginal,
    PagePaper.paper => l.paperPaper,
    PagePaper.sepia => l.paperSepia,
    PagePaper.green => l.paperGreen,
    PagePaper.gray => l.paperGray,
    PagePaper.dark => l.paperDark,
    PagePaper.black => l.paperBlack,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final enabled = _tint.paper != PagePaper.original;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(l.pageColor, style: theme.textTheme.titleMedium),
            Wrap(
              spacing: 4,
              runSpacing: 12,
              children: [
                for (final paper in PagePaper.values)
                  _Swatch(
                    tint: PageTint(paper: paper),
                    label: _name(l, paper),
                    selected: paper == _tint.paper,
                    onTap: () => _set(_tint.copyWith(paper: paper)),
                  ),
              ],
            ),
            _LabeledSlider(
              label: l.strength,
              value: _tint.strength,
              min: 0.2,
              onChanged: enabled
                  ? (v) => _set(_tint.copyWith(strength: v))
                  : null,
            ),
            _LabeledSlider(
              label: l.contrast,
              value: _tint.contrast,
              min: PageTint.minContrast,
              onChanged: enabled
                  ? (v) => _set(_tint.copyWith(contrast: v))
                  : null,
            ),
            _LabeledSlider(
              label: l.textWeight,
              value: _tint.weight,
              min: 0,
              onChanged: (v) => _set(_tint.copyWith(weight: v)),
            ),
            Text(
              l.pageColorHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.tint,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final PageTint tint;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 60,
          child: Column(
            spacing: 4,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.paperColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: ExcludeSemantics(
                  child: Text(
                    'Aa',
                    style: TextStyle(
                      color: tint.inkColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Text(label, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label)),
        Expanded(
          child: Semantics(
            label: label,
            child: CupertinoSlider(
              min: min,
              max: 1,
              value: value.clamp(min, 1),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
