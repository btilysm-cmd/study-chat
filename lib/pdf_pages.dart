import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

/// One rendered page image of a PDF.
class PdfImagePage {
  const PdfImagePage(this.page, this.path);

  final int page;
  final String path;
}

/// Which PDF pages need the vision model instead of the text extractor.
class PdfImagePlan {
  const PdfImagePlan({
    required this.pageCount,
    required this.imagePageCount,
    required this.pages,
  });

  final int pageCount;

  /// Pages detected as image-only / nearly text-free, before the render cap.
  final int imagePageCount;
  final List<PdfImagePage> pages;

  /// True when the whole document has no usable text layer.
  bool get allPagesAreImages => pageCount > 0 && imagePageCount == pageCount;

  static const empty = PdfImagePlan(pageCount: 0, imagePageCount: 0, pages: []);

  /// Analyze a PDF and render its image pages (cached next to the app data).
  ///
  /// Pages whose text layer has fewer than [textThreshold] visible characters
  /// are treated as scanned/image pages. At most [maxPages] are rendered.
  static Future<PdfImagePlan> prepare(
    String pdfPath, {
    int maxPages = 20,
    int textThreshold = 40,
    double width = 1440,
  }) async {
    final file = File(pdfPath);
    if (!file.existsSync()) return empty;
    final stat = file.statSync();
    final dir = await _cacheDir(pdfPath, stat);
    final planFile = File('${dir.path}/plan.json');
    if (planFile.existsSync()) {
      final cached = _readPlan(planFile);
      if (cached != null &&
          cached.pages.every((page) => File(page.path).existsSync())) {
        return cached;
      }
    }

    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(pdfPath);
      final pages = document.pages;
      final imagePages = <int>[];
      for (var i = 0; i < pages.length; i++) {
        final raw = await pages[i].loadText();
        final text = (raw?.fullText ?? '').replaceAll(RegExp(r'\s+'), '');
        if (text.length < textThreshold) imagePages.add(i + 1);
      }

      if (!dir.existsSync()) await dir.create(recursive: true);
      final rendered = <PdfImagePage>[];
      for (final pageNumber in imagePages.take(maxPages)) {
        final page = pages[pageNumber - 1];
        final fullHeight = width * page.height / page.width;
        final image = await page.render(
          fullWidth: width,
          fullHeight: fullHeight,
          backgroundColor: 0xFFFFFFFF,
        );
        if (image == null) continue;
        try {
          final jpeg = img.encodeJpg(image.createImageNF(), quality: 80);
          final target = File('${dir.path}/p$pageNumber.jpg');
          await target.writeAsBytes(jpeg, flush: true);
          rendered.add(PdfImagePage(pageNumber, target.path));
        } finally {
          image.dispose();
        }
      }

      final plan = PdfImagePlan(
        pageCount: pages.length,
        imagePageCount: imagePages.length,
        pages: rendered,
      );
      await planFile.writeAsString(
        jsonEncode({
          'pageCount': plan.pageCount,
          'imagePageCount': plan.imagePageCount,
          'pages': plan.pages
              .map((page) => {'page': page.page, 'path': page.path})
              .toList(),
        }),
        flush: true,
      );
      return plan;
    } catch (_) {
      return empty;
    } finally {
      await document?.dispose();
    }
  }

  static PdfImagePlan? _readPlan(File planFile) {
    try {
      final json = jsonDecode(planFile.readAsStringSync()) as Map;
      final pages = ((json['pages'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => PdfImagePage(
              (item['page'] as num).toInt(),
              item['path'] as String,
            ),
          )
          .toList();
      return PdfImagePlan(
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
        imagePageCount: (json['imagePageCount'] as num?)?.toInt() ?? 0,
        pages: pages,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _cacheDir(String pdfPath, FileStat stat) async {
    final root = await getApplicationDocumentsDirectory();
    final key = _stableKey(
      '$pdfPath|${stat.size}|${stat.modified.millisecondsSinceEpoch}',
    );
    return Directory('${root.path}/pdf_pages/$key');
  }

  static String _stableKey(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
