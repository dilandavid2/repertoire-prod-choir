import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

class ImportedScoreAsset {
  final String mode; // score_image | score_pdf
  final List<String> pages;
  final String originalName;

  const ImportedScoreAsset({
    required this.mode,
    required this.pages,
    required this.originalName,
  });
}

class ScoreFileImporter {
  Future<ImportedScoreAsset?> pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );

    if (result == null || result.files.isEmpty) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${appDir.path}/score_images');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final savedPaths = <String>[];

    for (final file in result.files) {
      final srcPath = file.path;
      if (srcPath == null) continue;

      final ext = file.extension ?? 'png';
      final safeName =
          '${DateTime.now().millisecondsSinceEpoch}_${savedPaths.length}.$ext';
      final destPath = '${targetDir.path}/$safeName';

      await File(srcPath).copy(destPath);
      savedPaths.add(destPath);
    }

    if (savedPaths.isEmpty) return null;

    return ImportedScoreAsset(
      mode: 'score_image',
      pages: savedPaths,
      originalName: result.files.first.name,
    );
  }

  Future<ImportedScoreAsset?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    final srcPath = picked.path;
    if (srcPath == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${appDir.path}/score_pdfs');
    final imgDir = Directory('${appDir.path}/score_pdf_pages');

    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }

    final baseName = DateTime.now().millisecondsSinceEpoch.toString();
    final savedPdfPath = '${pdfDir.path}/$baseName.pdf';
    await File(srcPath).copy(savedPdfPath);

    final document = await PdfDocument.openFile(savedPdfPath);
    final pagePaths = <String>[];

    try {
      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        try {
          final rendered = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );

          if (rendered?.bytes == null) continue;

          final pagePath = '${imgDir.path}/${baseName}_page_$i.png';
          final outFile = File(pagePath);
          await outFile.writeAsBytes(
            Uint8List.fromList(rendered!.bytes),
            flush: true,
          );
          pagePaths.add(pagePath);
        } finally {
          await page.close();
        }
      }
    } finally {
      await document.close();
    }

    if (pagePaths.isEmpty) return null;

    return ImportedScoreAsset(
      mode: 'score_pdf',
      pages: pagePaths,
      originalName: picked.name,
    );
  }
}