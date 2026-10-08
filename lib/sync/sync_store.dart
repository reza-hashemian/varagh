import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// A file in a [SyncStore]. [tag] changes whenever the content does.
class RemoteFile {
  const RemoteFile(this.name, this.tag);

  final String name;
  final String tag;
}

/// Where synced data is kept: a folder of small state files and book files.
/// Paths use forward slashes and are relative to the store's root.
abstract class SyncStore {
  /// Files directly inside [dir]; an absent folder lists as empty.
  Future<List<RemoteFile>> list(String dir);

  Future<Uint8List> read(String path);

  Future<void> write(String path, Uint8List bytes);

  Future<void> upload(String path, File source);

  Future<void> download(String path, File target);
}

/// Sync through a folder on this machine, such as one that a cloud drive
/// client or Syncthing mirrors to other devices.
class FolderSyncStore implements SyncStore {
  FolderSyncStore(this.root);

  final String root;

  File _file(String path) => File(p.joinAll([root, ...path.split('/')]));

  @override
  Future<List<RemoteFile>> list(String dir) async {
    final folder = Directory(p.joinAll([root, ...dir.split('/')]));
    if (!await folder.exists()) return const [];
    final files = <RemoteFile>[];
    await for (final entity in folder.list()) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      files.add(
        RemoteFile(
          p.basename(entity.path),
          '${stat.modified.millisecondsSinceEpoch}-${stat.size}',
        ),
      );
    }
    return files;
  }

  @override
  Future<Uint8List> read(String path) => _file(path).readAsBytes();

  @override
  Future<void> write(String path, Uint8List bytes) async {
    final file = _file(path);
    await file.parent.create(recursive: true);
    // Written beside the target and renamed, so a client mirroring the
    // folder never picks up half a file.
    final part = File('${file.path}.part');
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(file.path);
  }

  @override
  Future<void> upload(String path, File source) async {
    final file = _file(path);
    await file.parent.create(recursive: true);
    final part = await source.copy('${file.path}.part');
    await part.rename(file.path);
  }

  @override
  Future<void> download(String path, File target) async {
    await target.parent.create(recursive: true);
    final part = await _file(path).copy('${target.path}.part');
    await part.rename(target.path);
  }
}
