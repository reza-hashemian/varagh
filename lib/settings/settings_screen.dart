import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/app_state.dart';
import '../core/mac_widgets.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../library/backup_actions.dart';
import '../sync/sync_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = AppScope.of(context);

    final looks = {
      AppLook.light: l.lookLight,
      AppLook.paper: l.lookPaper,
      AppLook.dark: l.lookDark,
      AppLook.black: l.lookBlack,
    };
    final accents = {
      AppAccent.blue: l.accentBlue,
      AppAccent.purple: l.accentPurple,
      AppAccent.pink: l.accentPink,
      AppAccent.red: l.accentRed,
      AppAccent.orange: l.accentOrange,
      AppAccent.green: l.accentGreen,
      AppAccent.graphite: l.accentGraphite,
    };

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: MacToolbar(title: l.settings),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 22,
                children: [
                  MacGroup(
                    header: l.appearance,
                    children: [
                      MacRow(
                        label: l.appearance,
                        below: Wrap(
                          spacing: 14,
                          runSpacing: 12,
                          children: [
                            for (final entry in looks.entries)
                              _LookTile(
                                look: entry.key,
                                label: entry.value,
                                selected: state.look == entry.key,
                                onTap: () => state.look = entry.key,
                              ),
                          ],
                        ),
                      ),
                      MacRow(
                        label: l.accentColor,
                        control: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 7,
                          children: [
                            for (final entry in accents.entries)
                              _AccentDot(
                                color: entry.key.resolve(theme.brightness),
                                label: entry.value,
                                selected: state.accent == entry.key,
                                onTap: () => state.accent = entry.key,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  MacGroup(
                    header: l.general,
                    children: [
                      MacRow(
                        label: l.language,
                        control: MacPopupButton<String>(
                          value: state.localeCode ?? '',
                          items: {
                            '': l.languageSystem,
                            'fa': 'فارسی',
                            'en': 'English',
                          },
                          onChanged: (v) =>
                              state.localeCode = v.isEmpty ? null : v,
                        ),
                      ),
                    ],
                  ),
                  MacGroup(
                    header: l.reading,
                    children: [
                      MacRow(
                        label: l.scrollSpeed,
                        control: Text(
                          '${localNumber(context, (state.scrollSpeed * 100).round())}٪',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        below: Row(
                          spacing: 8,
                          children: [
                            Text(l.slower, style: theme.textTheme.bodySmall),
                            Expanded(
                              child: Semantics(
                                label: l.scrollSpeed,
                                child: CupertinoSlider(
                                  min: 0.25,
                                  max: 3,
                                  divisions: 11,
                                  value: state.scrollSpeed.clamp(0.25, 3),
                                  onChanged: (v) => state.scrollSpeed = v,
                                ),
                              ),
                            ),
                            Text(l.faster, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      MacRow(
                        label: l.smoothScrolling,
                        control: CupertinoSwitch(
                          value: state.smoothScroll,
                          onChanged: (v) => state.smoothScroll = v,
                        ),
                      ),
                    ],
                  ),
                  const _SyncGroup(),
                  MacGroup(
                    header: l.backup,
                    children: [
                      MacRow(
                        label: l.exportLibrary,
                        control: OutlinedButton(
                          onPressed: () => exportBackupFrom(context),
                          child: Text(l.export),
                        ),
                        below: Text(
                          l.exportLibraryHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      MacRow(
                        label: l.importBackup,
                        control: OutlinedButton(
                          onPressed: () => importBackupInto(context),
                          child: Text(l.chooseFile),
                        ),
                        below: Text(
                          l.importBackupHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  MacGroup(
                    header: l.about,
                    children: [
                      MacRow(
                        label: l.version,
                        control: Text(
                          '0.4.0',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      MacRow(label: l.storedOnDevice),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncGroup extends StatefulWidget {
  const _SyncGroup();

  @override
  State<_SyncGroup> createState() => _SyncGroupState();
}

class _SyncGroupState extends State<_SyncGroup> {
  late final AppState _state = AppScope.read(context);
  final _id = TextEditingController();
  final _secret = TextEditingController();
  SyncKind? _shown;

  @override
  void dispose() {
    _id.dispose();
    _secret.dispose();
    super.dispose();
  }

  /// Fills the key fields when the chosen provider changes.
  void _loadKeys(SyncKind kind) {
    if (_shown == kind) return;
    _shown = kind;
    _id.text = _state.sync.clientId(kind);
    _secret.text = _state.sync.clientSecret(kind);
  }

  void _saveKeys() => _state.sync.setCredentials(
    _state.sync.kind,
    id: _id.text.trim(),
    secret: _secret.text.trim(),
  );

  Future<void> _signIn() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _saveKeys();
    try {
      await _state.sync.signInToCloud(donePage: l.signInDonePage);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l.signInFailed}\n$error')),
      );
    }
  }

  void _showGuide(SyncKind kind) {
    final l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.howToGetKeys),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: SelectableText(
              kind == SyncKind.google ? l.googleGuide : l.microsoftGuide,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.9),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sync = _state.sync;
    final soft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget keyField(TextEditingController controller) => SizedBox(
      width: 300,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: TextField(
          controller: controller,
          style: theme.textTheme.bodySmall,
          onSubmitted: (_) => _saveKeys(),
          onTapOutside: (_) => _saveKeys(),
        ),
      ),
    );

    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final kind = sync.kind;
        if (sync.isCloud) _loadKeys(kind);

        final String status;
        if (sync.isRunning) {
          status = l.syncing;
        } else if (sync.error != null) {
          status = sync.isCloud ? l.syncFailedCloud : l.syncFailed;
        } else if (sync.lastSync == null) {
          status = l.neverSynced;
        } else {
          final code = Localizations.localeOf(context).languageCode;
          status = l.lastSynced(
            '${localDate(context, sync.lastSync!, alwaysYear: false)} '
            '${DateFormat.Hm(code).format(sync.lastSync!)}',
          );
        }

        return MacGroup(
          header: l.sync,
          children: [
            MacRow(
              label: l.syncMethod,
              control: MacPopupButton<SyncKind>(
                value: kind,
                items: {
                  SyncKind.off: l.syncOff,
                  SyncKind.folder: l.syncFolder,
                  SyncKind.google: l.syncGoogle,
                  SyncKind.microsoft: l.syncMicrosoft,
                },
                onChanged: (kind) => sync.kind = kind,
              ),
            ),
            if (kind == SyncKind.folder)
              MacRow(
                label: l.folder,
                control: OutlinedButton(
                  onPressed: () async {
                    final path = await FilePicker.getDirectoryPath();
                    if (path != null) sync.folder = path;
                  },
                  child: Text(l.chooseFolder),
                ),
                below: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: SelectableText(
                        sync.folder ?? l.noFolder,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(l.syncFolderHint, style: soft),
                  ],
                ),
              ),
            if (sync.isCloud) ...[
              MacRow(
                label: l.howToGetKeys,
                control: OutlinedButton(
                  onPressed: () => _showGuide(kind),
                  child: Text(l.howToGetKeys),
                ),
                below: Text(l.ownKeysHint, style: soft),
              ),
              MacRow(label: l.clientId, control: keyField(_id)),
              if (kind == SyncKind.google)
                MacRow(label: l.clientSecret, control: keyField(_secret)),
              MacRow(
                label: sync.isSigningIn
                    ? l.waitingForBrowser
                    : sync.isSignedIn
                    ? l.signedIn
                    : l.signInWithBrowser,
                control: sync.isSignedIn
                    ? OutlinedButton(
                        onPressed: sync.signOut,
                        child: Text(l.signOut),
                      )
                    : FilledButton(
                        onPressed: sync.isSigningIn ? null : _signIn,
                        child: Text(l.signInWithBrowser),
                      ),
              ),
            ],
            if (kind != SyncKind.off) ...[
              MacRow(
                label: l.syncBookFiles,
                control: CupertinoSwitch(
                  value: sync.syncFiles,
                  onChanged: (v) => sync.syncFiles = v,
                ),
              ),
              MacRow(
                label: l.thisDevice,
                control: Text(_state.library.deviceName, style: soft),
              ),
              MacRow(
                label: status,
                control: FilledButton(
                  onPressed: sync.isConfigured && !sync.isRunning
                      ? sync.syncNow
                      : null,
                  child: Text(l.syncNow),
                ),
                below: sync.error == null
                    ? null
                    : Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          sync.error!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: soft?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Miniature window drawn in a look's own colors.
class _LookTile extends StatelessWidget {
  const _LookTile({
    required this.look,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppLook look;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (content, sidebar, ink) = lookPreview(look);
    Widget line(double width) => Container(
      width: width,
      height: 3,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(2),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          spacing: 5,
          children: [
            Container(
              width: 76,
              height: 50,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(width: 20, color: sidebar),
                      Expanded(
                        child: Container(
                          color: content,
                          padding: const EdgeInsets.all(7),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [line(30), line(22), line(26)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ExcludeSemantics(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: selected
                ? const Icon(
                    CupertinoIcons.circle_fill,
                    size: 7,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
