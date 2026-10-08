import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/mac_widgets.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'highlight_colors.dart';

/// What an annotation is called in lists: a highlight's own words, what a
/// sticky note says, or the name of its kind.
String annotationLabel(AppLocalizations l, Annotation annotation) =>
    switch (annotation.kind) {
      AnnotationKind.highlight => annotation.text,
      AnnotationKind.ink =>
        annotation.text.isEmpty ? l.handwriting : annotation.text,
      AnnotationKind.sticky =>
        annotation.note.isEmpty ? l.stickyNote : annotation.note,
      AnnotationKind.page => l.attachedPage,
    };

/// List of a book's highlights: tapping one jumps to it on the page.
class HighlightsPanel extends StatelessWidget {
  const HighlightsPanel({
    super.key,
    required this.annotations,
    required this.onOpen,
    required this.onEdit,
  });

  final List<Annotation> annotations;
  final ValueChanged<Annotation> onOpen;
  final ValueChanged<Annotation> onEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final soft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLowest,
      child: annotations.isEmpty
          ? EmptyState(
              icon: Icons.border_color_outlined,
              title: l.noHighlightsTitle,
              body: l.noHighlightsBody,
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: annotations.length,
              separatorBuilder: (_, _) =>
                  const Divider(indent: 14, endIndent: 14),
              itemBuilder: (context, i) {
                final annotation = annotations[i];
                return InkWell(
                  onTap: () => onOpen(annotation),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 14,
                      end: 4,
                      top: 10,
                      bottom: 10,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 10,
                        children: [
                          Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: annotation.color.swatch,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 4,
                              children: [
                                Text(
                                  annotationLabel(l, annotation),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (annotation.note.isNotEmpty &&
                                    annotation.kind != AnnotationKind.sticky)
                                  Text(
                                    annotation.note,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                Text(
                                  l.pageN(
                                    localNumber(context, annotation.page),
                                  ),
                                  style: soft,
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: MacIconButton(
                              icon: CupertinoIcons.ellipsis,
                              tooltip: l.edit,
                              onPressed: () => onEdit(annotation),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
