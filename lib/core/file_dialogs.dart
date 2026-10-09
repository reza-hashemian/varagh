import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Asks where to save a file called [name] and puts [bytes] there. Returns
/// whether it was saved.
Future<bool> saveBytesAs(String name, Uint8List bytes) async =>
    await FilePicker.saveFile(fileName: name, bytes: bytes) != null;

/// Asks where to save a file called [name] and copies [file] there.
/// Returns whether it was saved.
Future<bool> saveFileAs(String name, File file) async {
  // A phone's save dialog only takes the whole content at once. A desktop
  // one answers with a path, so a big file is copied there without being
  // read into memory.
  if (Platform.isAndroid || Platform.isIOS) {
    return saveBytesAs(name, await file.readAsBytes());
  }
  final uri = await FilePicker.saveFile(fileName: name, bytes: Uint8List(0));
  if (uri == null || !uri.isScheme('file')) return false;
  await file.copy(uri.toFilePath());
  return true;
}

/// Runs [work] behind a dialog that says [label] and can't be dismissed.
Future<T> runBusy<T>(
  BuildContext context,
  String label,
  Future<T> Function() work,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          spacing: 14,
          children: [
            const CupertinoActivityIndicator(),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    ),
  );
  try {
    return await work();
  } finally {
    navigator.pop();
  }
}
