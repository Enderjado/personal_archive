import 'dart:typed_data' show Uint8List;

import 'package:personal_archive/src/application/pdf_page_image_renderer.dart';
import 'package:personal_archive/src/domain/ocr_types.dart';

/// A minimal 1×1 white PNG used as the default [MemoryOcrInput] bytes.
///
/// This is a valid PNG bytestream so it can be passed to any code that
/// inspects the image header, while keeping the test helper self-contained
/// without any asset files.
final Uint8List _kMinimalPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk length + type
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // width=1, height=1
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, // 8-bit RGB, CRC
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
  0x54, 0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0xCC, 0x59,
  0xE7, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND chunk
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Test double for [PdfPageImageRenderer] that returns a fixed [OcrInput]
/// for every page, decoupling OCR pipeline tests from real PDF rendering and
/// platform image APIs.
///
/// By default, each call returns a [MemoryOcrInput] backed by [_kMinimalPng].
/// Pass a custom [fixedInput] to control exactly what the OCR engine receives.
///
/// The [renderCalls] list records every `(pdfPath, pageNumber)` pair that was
/// requested, enabling assertions about which pages the pipeline actually
/// rendered.
class MockPdfPageImageRenderer implements PdfPageImageRenderer {
  MockPdfPageImageRenderer({OcrInput? fixedInput})
      : _fixedInput = fixedInput ??
            MemoryOcrInput(_kMinimalPng, width: 1, height: 1);

  final OcrInput _fixedInput;

  /// All `(pdfPath, pageNumber)` pairs received, in call order.
  final List<(String, int)> renderCalls = [];

  @override
  Future<OcrInput> renderPage(String pdfPath, int pageNumber) async {
    renderCalls.add((pdfPath, pageNumber));
    return _fixedInput;
  }
}
