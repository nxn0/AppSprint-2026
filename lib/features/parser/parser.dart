import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../data/models.dart';
import '../../services/local_flashcard_engine.dart';

class FlashcardParser {
  static List<Flashcard> parse(
    String text, {
    int maxCards = LocalFlashcardEngine.defaultMaxCards,
    String source = '',
  }) =>
      LocalFlashcardEngine.generate(
        text,
        maxCards: maxCards,
        source: source,
      );
}

class PdfTextExtractorService {
  static Future<String> extract(Uint8List bytes, {int maxPages = 5}) async {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final pageCount =
          document.pages.count < maxPages ? document.pages.count : maxPages;
      return List.generate(
        pageCount,
        (index) => extractor.extractText(
          startPageIndex: index,
          endPageIndex: index,
        ),
      ).join('\n');
    } finally {
      document.dispose();
    }
  }
}
