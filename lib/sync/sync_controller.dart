import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/importer.dart';
import '../data/library.dart';
import 'cloud_stores.dart';
import 'oauth.dart';
import 'sync_engine.dart';
import 'sync_store.dart';

enum SyncKind { off, folder, google, microsoft }

/// Settings keys of a cloud provider's credentials. They live in the local
/// settings table, which never syncs.
extension on SyncKind {
  String get _idKey => 'sync.$name.id';
  String get _secretKey => 'sync.$name.secret';
  String get _refreshKey => 'sync.$name.refresh';
}

/// Owns the sync settings and runs syncs: once at launch, when the app
/// goes to the background or returns, a few seconds after local changes,
/// and on demand. It never polls.
class SyncController extends ChangeNotifier with WidgetsBindingObserver {
  SyncController(this.library, {required this.onMerged}) {
    _kind =
        SyncKind.values.asNameMap()[library.setting('sync.kind')] ??
        SyncKind.off;
    _folder = library.setting('sync.folder');
    _syncFiles = library.setting('sync.files') != '0';
    final last = int.tryParse(library.setting('sync.last') ?? '');
    _lastSync = last == null ? null : DateTime.fromMillisecondsSinceEpoch(last);
    WidgetsBinding.instance.addObserver(this);
  }

  final Library library;

  /// Called when a sync changed local data, so screens can reload.
  final VoidCallback onMerged;

  static const _changeDelay = Duration(seconds: 6);

  late SyncKind _kind;
  String? _folder;
  late bool _syncFiles;
  DateTime? _lastSync;
  String? _error;
  var _running = false;
  var _signingIn = false;

  /// Access token of the current cloud account, kept in memory only.
  OAuthTokens? _tokens;
  var _again = false;
  Timer? _timer;

  SyncKind get kind => _kind;
  set kind(SyncKind value) {
    if (value == _kind) return;
    _kind = value;
    library.setSetting('sync.kind', value.name);
    _tokens = null;
    _error = null;
    notifyListeners();
    syncNow();
  }

  String? get folder => _folder;
  set folder(String? value) {
    if (value == _folder) return;
    _folder = value;
    library.setSetting('sync.folder', value);
    _error = null;
    notifyListeners();
    syncNow();
  }

  /// Whether book files travel too, or only positions, notes and tasks.
  bool get syncFiles => _syncFiles;
  set syncFiles(bool value) {
    if (value == _syncFiles) return;
    _syncFiles = value;
    library.setSetting('sync.files', value ? '1' : '0');
    notifyListeners();
    if (value) syncNow();
  }

  bool get isCloud => _kind == SyncKind.google || _kind == SyncKind.microsoft;

  bool get isConfigured => switch (_kind) {
    SyncKind.off => false,
    SyncKind.folder => _folder != null,
    _ => isSignedIn,
  };

  // Cloud accounts. The app has no keys of its own: each user registers an
  // app with the provider and enters its client id here.

  String clientId(SyncKind kind) => library.setting(kind._idKey) ?? '';
  String clientSecret(SyncKind kind) => library.setting(kind._secretKey) ?? '';

  /// Stores the keys of the user's own app registration. Changing them
  /// signs out, since tokens belong to the registration that issued them.
  void setCredentials(SyncKind kind, {required String id, String secret = ''}) {
    if (id == clientId(kind) && secret == clientSecret(kind)) return;
    library.setSetting(kind._idKey, id.isEmpty ? null : id);
    library.setSetting(kind._secretKey, secret.isEmpty ? null : secret);
    library.setSetting(kind._refreshKey, null);
    _tokens = null;
    notifyListeners();
  }

  bool get isSignedIn => library.setting(_kind._refreshKey) != null;
  bool get isSigningIn => _signingIn;

  OAuthConfig _oauth(SyncKind kind) => kind == SyncKind.google
      ? OAuthConfig(
          authorizeUrl: Uri.parse(
            'https://accounts.google.com/o/oauth2/v2/auth',
          ),
          tokenUrl: Uri.parse('https://oauth2.googleapis.com/token'),
          clientId: clientId(kind),
          clientSecret: clientSecret(kind),
          // Only the app's own hidden folder, not the user's files.
          scopes: const ['https://www.googleapis.com/auth/drive.appdata'],
          // Without these Google gives no refresh token.
          extraAuthParams: const {
            'access_type': 'offline',
            'prompt': 'consent',
          },
        )
      : OAuthConfig(
          authorizeUrl: Uri.parse(
            'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
          ),
          tokenUrl: Uri.parse(
            'https://login.microsoftonline.com/common/oauth2/v2.0/token',
          ),
          clientId: clientId(kind),
          // Only the app's own folder under Apps.
          scopes: const ['Files.ReadWrite.AppFolder', 'offline_access'],
          redirectHost: 'localhost',
        );

  /// Opens the browser for the user to approve access. [donePage] is what
  /// the browser shows afterwards. Throws [OAuthException] on failure.
  Future<void> signInToCloud({required String donePage}) async {
    final kind = _kind;
    if (!isCloud || _signingIn) return;
    _signingIn = true;
    _error = null;
    notifyListeners();
    try {
      final tokens = await signIn(
        _oauth(kind),
        donePage: donePage,
        openBrowser: (url) async {
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            throw const OAuthException('Could not open the browser');
          }
        },
      );
      if (tokens.refreshToken == null) {
        throw const OAuthException('The provider gave no lasting sign-in');
      }
      library.setSetting(kind._refreshKey, tokens.refreshToken);
      _tokens = tokens;
    } finally {
      _signingIn = false;
      notifyListeners();
    }
    unawaited(syncNow());
  }

  void signOut() {
    library.setSetting(_kind._refreshKey, null);
    _tokens = null;
    _error = null;
    notifyListeners();
  }

  /// A valid access token for [kind], renewed when it has run out.
  Future<String> _accessToken(SyncKind kind) async {
    final current = _tokens;
    if (current != null && DateTime.now().isBefore(current.expiresAt)) {
      return current.accessToken;
    }
    final refresh = library.setting(kind._refreshKey);
    if (refresh == null) throw const OAuthException('Not signed in');
    final tokens = await refreshTokens(_oauth(kind), refresh);
    // Microsoft hands out a new refresh token each time; Google keeps one.
    if (tokens.refreshToken != null) {
      library.setSetting(kind._refreshKey, tokens.refreshToken);
    }
    _tokens = tokens;
    return tokens.accessToken;
  }

  bool get isRunning => _running;
  DateTime? get lastSync => _lastSync;

  /// Why the last sync failed, or null if it succeeded.
  String? get error => _error;

  SyncStore? get _store {
    if (!isConfigured) return null;
    final kind = _kind;
    return switch (kind) {
      SyncKind.off => null,
      SyncKind.folder => FolderSyncStore(_folder!),
      SyncKind.google => GoogleDriveStore(
        accessToken: () => _accessToken(kind),
      ),
      SyncKind.microsoft => OneDriveStore(
        accessToken: () => _accessToken(kind),
      ),
    };
  }

  /// Syncs soon; repeated calls within the delay collapse into one.
  void schedule() {
    if (!isConfigured) return;
    _timer?.cancel();
    _timer = Timer(_changeDelay, syncNow);
  }

  Future<void> syncNow() async {
    _timer?.cancel();
    final store = _store;
    if (store == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    notifyListeners();
    try {
      final report = await SyncEngine(
        library,
        store,
        syncBookFiles: _syncFiles,
        onBookArrived: (book) => renderCoverFor(library, book),
      ).run();
      _error = null;
      _lastSync = DateTime.now();
      library.setSetting('sync.last', '${_lastSync!.millisecondsSinceEpoch}');
      if (report.rowsMerged > 0 || report.booksDownloaded > 0) onMerged();
    } catch (e) {
      _error = '$e';
    } finally {
      _running = false;
      notifyListeners();
      if (_again) {
        _again = false;
        unawaited(syncNow());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      syncNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
