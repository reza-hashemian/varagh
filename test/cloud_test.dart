import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:varagh/core/db.dart';
import 'package:varagh/data/library.dart';
import 'package:varagh/sync/cloud_stores.dart';
import 'package:varagh/sync/oauth.dart';
import 'package:varagh/sync/sync_engine.dart';
import 'package:varagh/sync/sync_store.dart';

/// Stands in for the Drive API: an app-data folder of files addressed by
/// id, listed two per page, uploaded through resumable sessions.
class FakeDrive {
  final files = <String, ({String name, Uint8List bytes})>{};
  final _sessions = <String, ({String? id, String? name})>{};
  late final HttpServer server;
  var _next = 1;

  Uri get base => Uri.parse('http://127.0.0.1:${server.port}');

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_handle);
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final response = request.response;
    void json(Object body, {int status = 200}) => response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));

    if (path.startsWith('/session/')) {
      final session = _sessions.remove(path.substring(9))!;
      final bytes = Uint8List.fromList(
        await request.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
      );
      final id = session.id ?? 'id${_next++}';
      files[id] = (name: session.name ?? files[id]!.name, bytes: bytes);
      json({'id': id, 'md5Checksum': md5.convert(bytes).toString()});
    } else if (request.headers.value('authorization') != 'Bearer drive-token') {
      json({
        'error': {'message': 'Invalid Credentials'},
      }, status: 401);
    } else if (path == '/drive/v3/files') {
      expect(request.uri.queryParameters['spaces'], 'appDataFolder');
      final all = files.entries.toList();
      final start = int.parse(request.uri.queryParameters['pageToken'] ?? '0');
      json({
        'files': [
          for (final entry in all.skip(start).take(2))
            {
              'id': entry.key,
              'name': entry.value.name,
              'md5Checksum': md5.convert(entry.value.bytes).toString(),
            },
        ],
        if (start + 2 < all.length) 'nextPageToken': '${start + 2}',
      });
    } else if (path.startsWith('/upload/drive/v3/files')) {
      expect(request.uri.queryParameters['uploadType'], 'resumable');
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      final existing = path.length > 23 ? path.substring(23) : null;
      if (existing == null) expect(body['parents'], ['appDataFolder']);
      final session = 's${_next++}';
      _sessions[session] = (id: existing, name: body['name'] as String?);
      response.headers.set('location', '$base/session/$session');
    } else if (path.startsWith('/drive/v3/files/')) {
      final file = files[path.substring(16)];
      if (file == null) {
        json({
          'error': {'message': 'File not found'},
        }, status: 404);
      } else {
        expect(request.uri.queryParameters['alt'], 'media');
        response.add(file.bytes);
      }
    } else {
      response.statusCode = 400;
    }
    await response.close();
  }
}

/// Stands in for Microsoft Graph's app folder: files addressed by path,
/// small ones PUT whole and large ones sent to an upload session in ranges.
class FakeGraph {
  final files = <String, Uint8List>{};
  final _uploads = <String, ({String path, BytesBuilder data})>{};
  final ranges = <String>[];
  late final HttpServer server;
  var _next = 1;

  Uri get base => Uri.parse('http://127.0.0.1:${server.port}/v1.0');

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_handle);
  }

  Future<void> _handle(HttpRequest request) async {
    final path = Uri.decodeFull(request.uri.path);
    final response = request.response;
    void json(Object body, {int status = 200}) => response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    Future<Uint8List> body() async => Uint8List.fromList(
      await request.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
    );

    if (path.startsWith('/upload/')) {
      final upload = _uploads[path.substring(8)]!;
      final range = request.headers.value('content-range')!;
      ranges.add(range);
      upload.data.add(await body());
      final total = int.parse(range.split('/').last);
      if (upload.data.length == total) {
        files[upload.path] = upload.data.takeBytes();
        json({'name': p.url.basename(upload.path)}, status: 201);
      } else {
        json({
          'nextExpectedRanges': ['${upload.data.length}-'],
        }, status: 202);
      }
      await response.close();
      return;
    }
    if (request.headers.value('authorization') != 'Bearer graph-token') {
      json({
        'error': {'message': 'Access token is empty.'},
      }, status: 401);
      await response.close();
      return;
    }
    const root = '/v1.0/me/drive/special/approot:/';
    final match = RegExp(r'^(.*):(/[A-Za-z]+)$')
        .firstMatch(path.substring(root.length))!;
    final item = match.group(1)!, action = match.group(2)!;
    switch ((request.method, action)) {
      case ('GET', '/children'):
        final inside = files.keys.where((k) => p.url.dirname(k) == item);
        if (inside.isEmpty) {
          json({
            'error': {'message': 'Item not found'},
          }, status: 404);
        } else {
          json({
            'value': [
              for (final key in inside)
                {
                  'name': p.url.basename(key),
                  'eTag': md5.convert(files[key]!).toString(),
                  'file': <String, Object>{},
                },
              {'name': 'a folder', 'eTag': 'x', 'folder': <String, Object>{}},
            ],
          });
        }
      case ('PUT', '/content'):
        files[item] = await body();
        json({'name': p.url.basename(item)}, status: 201);
      case ('GET', '/content'):
        final file = files[item];
        if (file == null) {
          json({
            'error': {'message': 'Item not found'},
          }, status: 404);
        } else {
          response.add(file);
        }
      case ('POST', '/createUploadSession'):
        final id = 'u${_next++}';
        _uploads[id] = (path: item, data: BytesBuilder());
        json({'uploadUrl': 'http://127.0.0.1:${server.port}/upload/$id'});
      default:
        response.statusCode = 400;
    }
    await response.close();
  }
}

void main() {
  late Directory root;
  var time = 1000;

  Library device(String name) => Library(
    openMemoryDatabase(),
    (Directory(p.join(root.path, name))..createSync()).path,
    clock: () => time++,
  );

  setUp(() => root = Directory.systemTemp.createTempSync('varagh_cloud'));
  tearDown(() => root.deleteSync(recursive: true));

  /// Syncs a note and a book file from one device to another through
  /// [store], the same way the folder-based sync is tested.
  Future<void> roundTrip(
    SyncStore Function() store, {
    int bookSize = 2000,
  }) async {
    final laptop = device('laptop'), phone = device('phone');
    final note = laptop.addNote(body: 'یادداشت همگام');
    final sha = 'ab' * 32;
    final book = laptop.addBook(
      id: sha.substring(0, 32),
      title: 'Book',
      format: 'pdf',
      fileName: '${sha.substring(0, 32)}.pdf',
      sha256: sha,
      size: bookSize,
      pageCount: 3,
    );
    Directory(laptop.booksDir).createSync(recursive: true);
    final content = Uint8List.fromList(
      List.generate(bookSize, (i) => i * 7 % 251),
    );
    laptop.fileOf(book).writeAsBytesSync(content);

    await SyncEngine(laptop, store()).run();
    final report = await SyncEngine(phone, store()).run();

    expect(phone.note(note.id)!.body, 'یادداشت همگام');
    expect(report.booksDownloaded, 1);
    expect(phone.fileOf(phone.book(book.id)!).readAsBytesSync(), content);

    // An edit made on the phone travels back and replaces the same file.
    phone.updateNote(note.id, 'ویرایش‌شده');
    await SyncEngine(phone, store()).run();
    await SyncEngine(laptop, store()).run();
    expect(laptop.note(note.id)!.body, 'ویرایش‌شده');
    final quiet = await SyncEngine(laptop, store()).run();
    expect(quiet.rowsMerged, 0);
    expect(quiet.booksUploaded, 0);
    laptop.db.close();
    phone.db.close();
  }

  group('Google Drive', () {
    late FakeDrive drive;
    setUp(() async {
      drive = FakeDrive();
      await drive.start();
    });
    tearDown(() => drive.server.close(force: true));

    GoogleDriveStore store([String token = 'drive-token']) =>
        GoogleDriveStore(accessToken: () async => token, apiBase: drive.base);

    test('two devices sync through the app folder', () async {
      await roundTrip(store);
      // One state file per device and the book, each stored once.
      expect(drive.files.values.map((f) => f.name).toSet(), hasLength(3));
      expect(drive.files, hasLength(3));
    });

    test('listing follows pages and strips the folder prefix', () async {
      for (final name in ['state/a', 'state/b', 'books/c', 'state/d']) {
        await store().write(name, Uint8List.fromList(utf8.encode(name)));
      }
      final names = (await store().list('state')).map((f) => f.name).toSet();
      expect(names, {'a', 'b', 'd'});
      expect(utf8.decode(await store().read('books/c')), 'books/c');
    });

    test('a rejected token surfaces the service message', () async {
      expect(
        () => store('expired').list('state'),
        throwsA(
          isA<CloudException>()
              .having((e) => e.status, 'status', 401)
              .having((e) => e.message, 'message', 'Invalid Credentials'),
        ),
      );
    });
  });

  group('OneDrive', () {
    late FakeGraph graph;
    setUp(() async {
      graph = FakeGraph();
      await graph.start();
    });
    tearDown(() => graph.server.close(force: true));

    OneDriveStore store() => OneDriveStore(
      accessToken: () async => 'graph-token',
      apiBase: graph.base,
      chunkSize: 2 * 1000 * 1000,
    );

    test('two devices sync through the app folder', () async {
      await roundTrip(store);
      expect(
        graph.files.keys.where((k) => k.startsWith('state/')),
        hasLength(2),
      );
      expect(
        graph.files.keys.where((k) => k.startsWith('books/')),
        hasLength(1),
      );
    });

    test('a folder that does not exist yet lists as empty', () async {
      expect(await store().list('state'), isEmpty);
    });

    test(
      'a large book goes up in ordered ranges and comes back whole',
      () async {
        await roundTrip(store, bookSize: 5 * 1000 * 1000);
        expect(graph.ranges, [
          'bytes 0-1999999/5000000',
          'bytes 2000000-3999999/5000000',
          'bytes 4000000-4999999/5000000',
        ]);
      },
    );
  });

  group('sign-in', () {
    late HttpServer provider;
    late OAuthConfig config;
    String? challenge;
    var granted = 0;

    setUp(() async {
      granted = 0;
      provider = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      provider.listen((request) async {
        final form = Uri.splitQueryString(
          await utf8.decoder.bind(request).join(),
        );
        final response = request.response
          ..headers.contentType = ContentType.json;
        final verifier = form['code_verifier'];
        final proven =
            verifier != null &&
            base64Url
                    .encode(sha256.convert(ascii.encode(verifier)).bytes)
                    .replaceAll('=', '') ==
                challenge;
        if (form['grant_type'] == 'authorization_code' &&
            form['code'] == 'one-time' &&
            form['client_id'] == 'my-client' &&
            form['client_secret'] == 'my-secret' &&
            proven) {
          response.write(
            jsonEncode({
              'access_token': 'access-${++granted}',
              'refresh_token': 'refresh-1',
              'expires_in': 3600,
            }),
          );
        } else if (form['grant_type'] == 'refresh_token' &&
            form['refresh_token'] == 'refresh-1') {
          response.write(jsonEncode({'access_token': 'access-${++granted}'}));
        } else {
          response
            ..statusCode = 400
            ..write(
              jsonEncode({
                'error': 'invalid_grant',
                'error_description': 'Bad request for token',
              }),
            );
        }
        await response.close();
      });
      config = OAuthConfig(
        authorizeUrl: Uri.parse('http://provider.test/authorize'),
        tokenUrl: Uri.parse('http://127.0.0.1:${provider.port}/token'),
        clientId: 'my-client',
        clientSecret: 'my-secret',
        scopes: const ['files', 'offline'],
      );
    });
    tearDown(() => provider.close(force: true));

    /// Plays the browser: checks what the app asked for, then lands on the
    /// app's loopback address the way the provider would send it.
    Future<void> Function(Uri) browser(
      Map<String, String> Function(Uri) reply,
    ) => (url) async {
      final query = url.queryParameters;
      expect(url.host, 'provider.test');
      expect(query['client_id'], 'my-client');
      expect(query['response_type'], 'code');
      expect(query['scope'], 'files offline');
      expect(query['code_challenge_method'], 'S256');
      challenge = query['code_challenge'];
      final redirect = Uri.parse(query['redirect_uri']!);
      expect(redirect.host, '127.0.0.1');
      // Not awaited: the app must be free to receive it.
      http.get(redirect.replace(path: '/favicon.ico')).ignore();
      http.get(redirect.replace(queryParameters: reply(url))).ignore();
    };

    test('a browser round trip yields tokens, proven by PKCE', () async {
      final tokens = await signIn(
        config,
        openBrowser: browser(
          (url) => {'code': 'one-time', 'state': url.queryParameters['state']!},
        ),
      );
      expect(tokens.accessToken, 'access-1');
      expect(tokens.refreshToken, 'refresh-1');
      expect(tokens.expiresAt.isAfter(DateTime.now()), isTrue);
    });

    test('a refresh token buys a new access token', () async {
      final tokens = await refreshTokens(config, 'refresh-1');
      expect(tokens.accessToken, 'access-1');
      expect(tokens.refreshToken, isNull);
      expect(
        () => refreshTokens(config, 'revoked'),
        throwsA(
          isA<OAuthException>().having(
            (e) => e.message,
            'message',
            'Bad request for token',
          ),
        ),
      );
    });

    test('a refusal or a forged reply ends the sign-in', () async {
      expect(
        () => signIn(
          config,
          openBrowser: browser(
            (_) => {'error': 'access_denied', 'error_description': 'No thanks'},
          ),
        ),
        throwsA(
          isA<OAuthException>().having(
            (e) => e.message,
            'message',
            'No thanks',
          ),
        ),
      );
      expect(
        () => signIn(
          config,
          openBrowser: browser((_) => {'code': 'one-time', 'state': 'forged'}),
        ),
        throwsA(isA<OAuthException>()),
      );
    });

    test('giving up waiting is reported', () async {
      expect(
        () => signIn(
          config,
          openBrowser: (_) async {},
          timeout: const Duration(milliseconds: 150),
        ),
        throwsA(
          isA<OAuthException>().having(
            (e) => e.message,
            'message',
            'Sign-in timed out',
          ),
        ),
      );
    });
  });
}
