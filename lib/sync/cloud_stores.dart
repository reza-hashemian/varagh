import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'sync_store.dart';

class CloudException implements Exception {
  const CloudException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => '$message ($status)';
}

/// Shared plumbing: every request carries a current access token and a
/// failure becomes a [CloudException].
abstract class _CloudStore implements SyncStore {
  _CloudStore(this._token, this._client);

  /// Returns a valid access token, refreshing it if need be.
  final Future<String> Function() _token;
  final http.Client _client;

  Future<http.Response> _send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
    bool allowMissing = false,
  }) async {
    final request = http.Request(method, url)
      ..headers.addAll(headers)
      ..headers['Authorization'] = 'Bearer ${await _token()}';
    if (body is List<int>) request.bodyBytes = body;
    if (body is String) request.body = body;
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode >= 400 &&
        !(allowMissing && response.statusCode == 404)) {
      throw CloudException(response.statusCode, _reason(response.body));
    }
    return response;
  }

  /// Streams a download to [target], writing beside it first so a failed
  /// transfer never leaves a truncated file in its place.
  Future<void> _downloadTo(Uri url, File target) async {
    final request = http.Request('GET', url)
      ..headers['Authorization'] = 'Bearer ${await _token()}';
    final response = await _client.send(request);
    if (response.statusCode >= 400) {
      throw CloudException(
        response.statusCode,
        _reason(await response.stream.bytesToString()),
      );
    }
    await target.parent.create(recursive: true);
    final part = File('${target.path}.part');
    await response.stream.pipe(part.openWrite());
    await part.rename(target.path);
  }

  static String _reason(String body) {
    try {
      final json = jsonDecode(body);
      final error = json is Map ? json['error'] : null;
      if (error is Map && error['message'] is String) return error['message'];
      if (error is String) return error;
    } on FormatException {
      // Not JSON; fall through to the generic message.
    }
    return 'The cloud service refused the request';
  }
}

/// Keeps synced files in the app's own hidden folder of a Google Drive.
///
/// That folder has no subfolders worth the trouble, so a path such as
/// `books/abc.pdf` is stored as a file with that whole string as its name.
class GoogleDriveStore extends _CloudStore {
  GoogleDriveStore({
    required Future<String> Function() accessToken,
    http.Client? client,
    Uri? apiBase,
  }) : _base = apiBase ?? Uri.parse('https://www.googleapis.com'),
       super(accessToken, client ?? http.Client());

  final Uri _base;

  /// Drive addresses files by id; this maps each name to its id and tag,
  /// loaded once per store.
  Map<String, ({String id, String tag})>? _files;

  Uri _url(String path, [Map<String, String>? query]) =>
      _base.replace(path: '${_base.path}$path', queryParameters: query);

  Future<Map<String, ({String id, String tag})>> _index() async {
    if (_files != null) return _files!;
    final files = <String, ({String id, String tag})>{};
    String? page;
    do {
      final response = await _send(
        'GET',
        _url('/drive/v3/files', {
          'spaces': 'appDataFolder',
          'fields': 'nextPageToken,files(id,name,md5Checksum,modifiedTime)',
          'pageSize': '1000',
          'pageToken': ?page,
        }),
      );
      final json = jsonDecode(response.body) as Map<String, Object?>;
      for (final file in (json['files'] as List? ?? const [])) {
        file as Map;
        files[file['name'] as String] = (
          id: file['id'] as String,
          tag: '${file['md5Checksum'] ?? file['modifiedTime']}',
        );
      }
      page = json['nextPageToken'] as String?;
    } while (page != null);
    return _files = files;
  }

  @override
  Future<List<RemoteFile>> list(String dir) async => [
    for (final entry in (await _index()).entries)
      if (entry.key.startsWith('$dir/'))
        RemoteFile(entry.key.substring(dir.length + 1), entry.value.tag),
  ];

  @override
  Future<Uint8List> read(String path) async {
    final id = (await _index())[path]?.id;
    if (id == null) throw CloudException(404, 'Not found: $path');
    final response = await _send(
      'GET',
      _url('/drive/v3/files/$id', {'alt': 'media'}),
    );
    return response.bodyBytes;
  }

  @override
  Future<void> write(String path, Uint8List bytes) =>
      _put(path, bytes.length, Stream.value(bytes));

  @override
  Future<void> upload(String path, File source) async =>
      _put(path, await source.length(), source.openRead());

  /// Uploads through a resumable session: one request to say what is
  /// coming, then the bytes streamed, so a large book never has to fit in
  /// memory.
  Future<void> _put(String path, int length, Stream<List<int>> bytes) async {
    final existing = (await _index())[path]?.id;
    final session = await _send(
      existing == null ? 'POST' : 'PATCH',
      _url('/upload/drive/v3/files${existing == null ? '' : '/$existing'}', {
        'uploadType': 'resumable',
        'fields': 'id,md5Checksum',
      }),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(
        existing == null
            ? {
                'name': path,
                'parents': ['appDataFolder'],
              }
            : <String, Object>{},
      ),
    );
    final location = session.headers['location'];
    if (location == null) {
      throw const CloudException(500, 'Upload could not be started');
    }
    final request = http.StreamedRequest('PUT', Uri.parse(location))
      ..contentLength = length
      ..headers['Authorization'] = 'Bearer ${await _token()}';
    bytes.listen(
      request.sink.add,
      onError: request.sink.addError,
      onDone: request.sink.close,
    );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode >= 400) {
      throw CloudException(
        response.statusCode,
        _CloudStore._reason(response.body),
      );
    }
    final json = jsonDecode(response.body) as Map<String, Object?>;
    _files![path] = (
      id: json['id'] as String,
      tag: '${json['md5Checksum'] ?? DateTime.now().toIso8601String()}',
    );
  }

  @override
  Future<void> download(String path, File target) async {
    final id = (await _index())[path]?.id;
    if (id == null) throw CloudException(404, 'Not found: $path');
    await _downloadTo(_url('/drive/v3/files/$id', {'alt': 'media'}), target);
  }
}

/// Keeps synced files in the app's own folder of a OneDrive
/// (under Apps, in a folder named after the app), through Microsoft Graph.
class OneDriveStore extends _CloudStore {
  OneDriveStore({
    required Future<String> Function() accessToken,
    http.Client? client,
    Uri? apiBase,
    this.chunkSize = 10 * 320 * 1024,
  }) : _base = apiBase ?? Uri.parse('https://graph.microsoft.com/v1.0'),
       super(accessToken, client ?? http.Client());

  final Uri _base;

  /// Bytes per request of a large upload. Graph wants multiples of 320 KiB.
  final int chunkSize;

  /// Files up to this size go up in a single request.
  static const _simpleUploadLimit = 4 * 1000 * 1000;

  Uri _item(String path, String action, [Map<String, String>? query]) {
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    return _base.replace(
      path: '${_base.path}/me/drive/special/approot:/$encoded:$action',
      queryParameters: query,
    );
  }

  @override
  Future<List<RemoteFile>> list(String dir) async {
    final files = <RemoteFile>[];
    Uri? next = _item(dir, '/children', {
      r'$select': 'name,eTag,file',
      r'$top': '200',
    });
    while (next != null) {
      // A folder nothing has been written to yet doesn't exist.
      final response = await _send('GET', next, allowMissing: true);
      if (response.statusCode == 404) break;
      final json = jsonDecode(response.body) as Map<String, Object?>;
      for (final item in (json['value'] as List? ?? const [])) {
        item as Map;
        if (item['file'] == null) continue;
        files.add(RemoteFile(item['name'] as String, '${item['eTag']}'));
      }
      final link = json['@odata.nextLink'] as String?;
      next = link == null ? null : Uri.parse(link);
    }
    return files;
  }

  @override
  Future<Uint8List> read(String path) async =>
      (await _send('GET', _item(path, '/content'))).bodyBytes;

  @override
  Future<void> write(String path, Uint8List bytes) async {
    await _send(
      'PUT',
      _item(path, '/content'),
      headers: {'Content-Type': 'application/octet-stream'},
      body: bytes,
    );
  }

  @override
  Future<void> upload(String path, File source) async {
    final length = await source.length();
    if (length <= _simpleUploadLimit) {
      return write(path, await source.readAsBytes());
    }
    final session = await _send(
      'POST',
      _item(path, '/createUploadSession'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'item': {'@microsoft.graph.conflictBehavior': 'replace'},
      }),
    );
    final uploadUrl = Uri.parse(
      (jsonDecode(session.body) as Map)['uploadUrl'] as String,
    );
    // The upload address carries its own authorization; chunks go up in
    // order, each saying which bytes of the whole it holds.
    final reader = await source.open();
    try {
      for (var start = 0; start < length; start += chunkSize) {
        final chunk = await reader.read(
          start + chunkSize > length ? length - start : chunkSize,
        );
        final response = await _client.put(
          uploadUrl,
          headers: {
            'Content-Range': 'bytes $start-${start + chunk.length - 1}/$length',
          },
          body: chunk,
        );
        if (response.statusCode >= 400) {
          throw CloudException(
            response.statusCode,
            _CloudStore._reason(response.body),
          );
        }
      }
    } finally {
      await reader.close();
    }
  }

  @override
  Future<void> download(String path, File target) =>
      _downloadTo(_item(path, '/content'), target);
}
