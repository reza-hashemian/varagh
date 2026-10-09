import 'dart:ffi' hide Size;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/painting.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';

import '../data/models.dart';
import '../draw/mark.dart';
import '../draw/mark_painter.dart';
import 'highlight_colors.dart';
import 'sticky_painter.dart';

/// Kinds of annotation an exported PDF can carry.
enum ExportPart { highlights, handwriting, shapes, text, stickies }

/// Which part of an export [annotation] belongs to; null for the ones that
/// only mean something inside the app, such as an attached notebook page.
ExportPart? exportPartOf(Annotation annotation) => switch (annotation.kind) {
  AnnotationKind.highlight => ExportPart.highlights,
  AnnotationKind.sticky => ExportPart.stickies,
  AnnotationKind.page => null,
  AnnotationKind.ink => switch (annotation.mark!) {
    Mark(tool: MarkTool.text) => ExportPart.text,
    Mark(isFreehand: true) => ExportPart.handwriting,
    _ => ExportPart.shapes,
  },
};

/// Pixels per PDF point that drawings are stored at, and the longest side
/// one of their pictures may have.
const _layerScale = 3.0;
const _maxLayerSide = 4096.0;

/// PDFium's FPDF_FILLMODE_WINDING.
const _fillWinding = 2;

/// Makes a copy of the PDF at [path] with [annotations] put onto its pages
/// and returns the new file's bytes.
///
/// The pages themselves are left as they are, so their text can still be
/// selected and searched: highlights are added as shapes, and everything
/// drawn or written goes on top as a see-through picture. With
/// [annotatedPagesOnly] the pages that got nothing are left out.
Future<Uint8List> exportAnnotatedPdf(
  String path,
  List<Annotation> annotations, {
  bool annotatedPagesOnly = false,
}) async {
  final document = await PdfDocument.openFile(path);
  try {
    final byPage = <int, List<Annotation>>{};
    for (final annotation in annotations) {
      if (exportPartOf(annotation) == null ||
          annotation.page < 1 ||
          annotation.page > document.pages.length) {
        continue;
      }
      (byPage[annotation.page] ??= []).add(annotation);
    }
    final lib = pdfium.getPdfium(modulePath: Pdfrx.pdfiumModulePath);
    for (final MapEntry(key: number, value: onPage) in byPage.entries) {
      final page = document.pages[number - 1];
      bool isMarker(Annotation a) => a.mark?.tool == MarkTool.marker;
      // A highlighter darkens what is under it, so its strokes go in a
      // picture of their own that the PDF blends that way.
      final markers = await _renderLayer(page, onPage.where(isMarker));
      final rest = await _renderLayer(page, onPage.where((a) => !isMarker(a)));
      await document.useNativeDocumentHandle(
        (handle) => _stamp(
          lib,
          pdfium.FPDF_DOCUMENT.fromAddress(handle),
          page,
          highlights: [
            for (final annotation in onPage)
              if (annotation.kind == AnnotationKind.highlight) annotation,
          ],
          multiplied: markers,
          plain: rest,
        ),
      );
    }
    if (annotatedPagesOnly) {
      final count = document.pages.length;
      await document.useNativeDocumentHandle((handle) {
        final native = pdfium.FPDF_DOCUMENT.fromAddress(handle);
        // From the end, so the pages still to go keep their places.
        for (var number = count; number >= 1; number--) {
          if (!byPage.containsKey(number)) {
            lib.FPDFPage_Delete(native, number - 1);
          }
        }
      });
    }
    return await document.encodePdf();
  } finally {
    await document.dispose();
  }
}

/// A picture of some annotations, cut down to the part of the page they
/// cover.
class _Layer {
  const _Layer(this.bgra, this.width, this.height, this.area);

  /// Pixels, four bytes each: blue, green, red, alpha.
  final Uint8List bgra;
  final int width, height;

  /// Where the picture sits on the page as it is shown, in PDF points from
  /// the top left.
  final Rect area;
}

/// Paints the drawings and sticky notes among [annotations] as they look on
/// [page]; null when there are none.
Future<_Layer?> _renderLayer(
  PdfPage page,
  Iterable<Annotation> annotations,
) async {
  final scale = math.min(
    _layerScale,
    _maxLayerSide / math.max(page.width, page.height),
  );
  final size = Size(page.width, page.height) * scale;
  Offset at(double x, double y) =>
      PdfRect(x, y, x, y).toRect(page: page, scaledPageSize: size).topLeft;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  var painted = false;
  for (final annotation in annotations) {
    final r = annotation.rects;
    switch (annotation.kind) {
      case AnnotationKind.ink:
        paintMark(canvas, annotation.mark!, at, scale, onPaper: false);
      case AnnotationKind.sticky when r.length >= 2:
        paintSticky(
          canvas,
          annotation,
          at(r[0], r[1]),
          scale,
          height: stickyHeight(annotation),
        );
      default:
        continue;
    }
    painted = true;
  }
  final picture = recorder.endRecording();
  if (!painted) {
    picture.dispose();
    return null;
  }
  final width = size.width.ceil(), height = size.height.ceil();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  image.dispose();
  if (data == null) return null;
  final rgba = data.buffer.asUint8List();

  // Most of the page is empty, so only the part that was drawn on is kept.
  var left = width, top = height, right = -1, bottom = -1;
  for (var y = 0; y < height; y++) {
    final row = y * width * 4 + 3;
    for (var x = 0; x < width; x++) {
      if (rgba[row + x * 4] == 0) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      bottom = y;
    }
  }
  if (right < 0) return null;
  final w = right - left + 1, h = bottom - top + 1;
  final bgra = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    var from = ((top + y) * width + left) * 4, to = y * w * 4;
    for (var x = 0; x < w; x++, from += 4, to += 4) {
      bgra[to] = rgba[from + 2];
      bgra[to + 1] = rgba[from + 1];
      bgra[to + 2] = rgba[from];
      bgra[to + 3] = rgba[from + 3];
    }
  }
  return _Layer(
    bgra,
    w,
    h,
    Rect.fromLTWH(left / scale, top / scale, w / scale, h / scale),
  );
}

/// Adds the highlights and pictures to [page] of the open PDFium [document].
void _stamp(
  pdfium.PDFium lib,
  pdfium.FPDF_DOCUMENT document,
  PdfPage page, {
  required List<Annotation> highlights,
  required _Layer? multiplied,
  required _Layer? plain,
}) {
  final native = lib.FPDF_LoadPage(document, page.pageNumber - 1);
  if (native == nullptr) return;
  using((arena) {
    // Annotations are placed from the corner of the page's visible box,
    // which need not be the origin of the page's own space.
    final box = arena<pdfium.FS_RECTF>();
    lib.FPDF_GetPageBoundingBox(native, box);
    final dx = box.ref.left, dy = box.ref.bottom;
    final multiply = 'Multiply'.toNativeUtf8(allocator: arena).cast<Char>();

    for (final highlight in highlights) {
      final r = highlight.rects;
      if (r.length < 4) continue;
      // One shape for all of a highlight's lines, so where two of them
      // overlap the text isn't darkened twice.
      final path = lib.FPDFPageObj_CreateNewPath(r[0] + dx, r[1] + dy);
      for (var i = 0; i + 3 < r.length; i += 4) {
        if (i > 0) lib.FPDFPath_MoveTo(path, r[i] + dx, r[i + 1] + dy);
        lib.FPDFPath_LineTo(path, r[i + 2] + dx, r[i + 1] + dy);
        lib.FPDFPath_LineTo(path, r[i + 2] + dx, r[i + 3] + dy);
        lib.FPDFPath_LineTo(path, r[i] + dx, r[i + 3] + dy);
        lib.FPDFPath_Close(path);
      }
      final color = highlight.color.marker;
      lib.FPDFPageObj_SetFillColor(
        path,
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        (color.a * 255).round(),
      );
      lib.FPDFPageObj_SetBlendMode(path, multiply);
      lib.FPDFPath_SetDrawMode(path, _fillWinding, 0);
      lib.FPDFPage_InsertObject(native, path);
    }

    final pages = arena<pdfium.FPDF_PAGE>()..value = native;
    for (final layer in [multiplied, plain]) {
      if (layer == null) continue;
      final bitmap = lib.FPDFBitmap_Create(layer.width, layer.height, 1);
      final stride = lib.FPDFBitmap_GetStride(bitmap);
      final pixels = lib.FPDFBitmap_GetBuffer(bitmap)
          .cast<Uint8>()
          .asTypedList(stride * layer.height);
      final rowBytes = layer.width * 4;
      for (var y = 0; y < layer.height; y++) {
        pixels.setRange(
          y * stride,
          y * stride + rowBytes,
          layer.bgra,
          y * rowBytes,
        );
      }
      final image = lib.FPDFPageObj_NewImageObj(document);
      lib.FPDFImageObj_SetBitmap(pages, 1, image, bitmap);
      lib.FPDFBitmap_Destroy(bitmap);
      // The matrix says where the picture's bottom left corner goes and
      // which way its bottom and left edges run, which is what turns it
      // along with a rotated page.
      final area = layer.area;
      final corner = area.bottomLeft.toPdfPoint(page: page);
      final across = area.bottomRight.toPdfPoint(page: page);
      final up = area.topLeft.toPdfPoint(page: page);
      lib.FPDFImageObj_SetMatrix(
        image,
        across.x - corner.x,
        across.y - corner.y,
        up.x - corner.x,
        up.y - corner.y,
        corner.x + dx,
        corner.y + dy,
      );
      if (identical(layer, multiplied)) {
        lib.FPDFPageObj_SetBlendMode(image, multiply);
      }
      lib.FPDFPage_InsertObject(native, image);
    }
    lib.FPDFPage_GenerateContent(native);
  });
  lib.FPDF_ClosePage(native);
}
