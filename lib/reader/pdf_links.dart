import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';

/// The file a link at a point of a page opens, if there is one there.
///
/// The viewer only knows links to web addresses and to other pages. A link
/// that opens a file, such as a video beside the book, is a "launch"
/// action, so it is looked up here. [x] and [y] are in the viewer's page
/// coordinates: PDF points from the bottom left of the visible page box.
Future<String?> fileLinkAt(
  PdfDocument document,
  int pageNumber,
  double x,
  double y,
) async {
  final lib = pdfium.getPdfium(modulePath: Pdfrx.pdfiumModulePath);
  return document.useNativeDocumentHandle((handle) {
    final native = pdfium.FPDF_DOCUMENT.fromAddress(handle);
    final page = lib.FPDF_LoadPage(native, pageNumber - 1);
    if (page == nullptr) return null;
    final box = calloc<pdfium.FS_RECTF>();
    try {
      // The viewer measures from the corner of the visible box, PDFium from
      // the page's own origin.
      lib.FPDF_GetPageBoundingBox(page, box);
      final link = lib.FPDFLink_GetLinkAtPoint(
        page,
        x + box.ref.left,
        y + box.ref.bottom,
      );
      if (link == nullptr) return null;
      final action = lib.FPDFLink_GetAction(link);
      if (action == nullptr) return null;
      final type = lib.FPDFAction_GetType(action);
      if (type != pdfium.PDFACTION_LAUNCH &&
          type != pdfium.PDFACTION_REMOTEGOTO) {
        return null;
      }
      final size = lib.FPDFAction_GetFilePath(action, nullptr, 0);
      if (size <= 1) return null;
      final buffer = calloc<Uint8>(size);
      try {
        lib.FPDFAction_GetFilePath(action, buffer.cast(), size);
        final path = buffer.cast<Utf8>().toDartString();
        // PDFium turns the PDF's slashes into the system's separator: a
        // backslash on Windows, which is a path there, but a colon on a
        // Mac, the separator of old Mac OS, which a Mac no longer takes.
        return Platform.isMacOS ? path.replaceAll(':', '/') : path;
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(box);
      lib.FPDF_ClosePage(page);
    }
  });
}
