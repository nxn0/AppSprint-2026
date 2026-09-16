import '../data/models.dart';

class LocalFlashcardEngine {
  static const int defaultMaxCards = 25;
  static const Set<String> _stopWords = {
    'the',
    'this',
    'that',
    'these',
    'those',
    'there',
    'here',
    'what',
    'when',
    'where',
    'which',
    'who',
    'whom',
    'whose',
    'each',
    'every',
    'some',
    'many',
    'most',
    'all',
    'both',
    'with',
    'from',
    'into',
    'during',
    'including',
    'until',
    'against',
    'among',
    'throughout',
    'despite',
    'towards',
    'upon',
    'concerning',
    'using',
    'for',
    'unlike',
    'also',
    'such',
    'then',
  };

  static final _bulletPattern = RegExp(
    r'^(.{8,180}?)\s*:\s*(?:o|[•▪·●])\s+(.+)[.!?]$',
    caseSensitive: false,
  );

  static List<Flashcard> generateCards(
    String rawText, {
    String source = '',
    int? maxCards,
  }) {
    if (rawText.trim().isEmpty) return const [];

    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !_isCodeSentence(line))
        .toList();
    final explicitCards = <Flashcard>[];
    final proseLines = <String>[];
    for (var index = 0; index < lines.length; index++) {
      var line = lines[index];
      if (RegExp(r'^Q\s*:', caseSensitive: false).hasMatch(line) &&
          index + 1 < lines.length &&
          RegExp(r'^A\s*:', caseSensitive: false).hasMatch(lines[index + 1])) {
        line = '$line ${lines[++index]}';
      }
      final pair = _explicitPair(line);
      if (pair == null) {
        proseLines.add(line);
      } else {
        explicitCards.add(_card(
          id: 'explicit_${DateTime.now().microsecondsSinceEpoch}_${explicitCards.length}',
          front: pair.$1,
          back: pair.$2,
          type: CardType.standard,
          source: source,
        ));
      }
    }
    final withoutCodeLines = proseLines.join(' ');
    final clean = withoutCodeLines.replaceAll(RegExp(r'\s+'), ' ').trim();
    final sentencePattern = RegExp(r'[^.!?]+(?:[.!?]|$)');
    final matches = sentencePattern.allMatches(clean);
    final cards = [...explicitCards];

    for (final match in matches) {
      final sentence = _removeRepeatedHeading(match.group(0)?.trim() ?? '');
      if (sentence.length < 25 || sentence.length > 250) continue;

      final lower = sentence.toLowerCase();
      if (lower.contains('table of contents') ||
          lower.contains('page ') ||
          lower.contains('chapter ') ||
          _isCodeSentence(sentence)) {
        continue;
      }

      final bullet = _bulletPattern.firstMatch(sentence);
      if (bullet != null) {
        final answer = bullet.group(2)!.trim();
        final question = _bulletQuestion(bullet.group(1)!);
        if (question != null && answer.isNotEmpty) {
          cards.add(_card(
            id: 'bullet_${DateTime.now().microsecondsSinceEpoch}_${cards.length}',
            front: question,
            back: answer,
            type: CardType.standard,
            source: source,
          ));
        }
        continue;
      }

      final definition = RegExp(
        r'\b([A-Z][a-zA-Z0-9_-]{1,30})\s+(?:is\s+defined\s+as|refers\s+to|is\s+used\s+(?:to|for)|is\s+a\s+type\s+of|is\s+an?\s+)([^.!?]{10,180})',
      ).firstMatch(sentence);

      if (definition != null) {
        final subject = definition.group(1)!.trim();
        final answer = definition.group(2)!.trim();
        cards.add(_card(
          id: 'def_${DateTime.now().microsecondsSinceEpoch}_${cards.length}',
          front: 'What is $subject?',
          back: answer,
          type: CardType.standard,
          source: source,
        ));
        continue;
      }

      String? targetWord;
      for (final word in sentence.split(RegExp(r'\s+'))) {
        if (word.contains('(') || word.contains(')')) continue;
        final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
        if (cleanWord.length >= 3 &&
            cleanWord[0] == cleanWord[0].toUpperCase() &&
            !_stopWords.contains(cleanWord.toLowerCase())) {
          targetWord = cleanWord;
          break;
        }
      }

      if (targetWord != null) {
        final clozeFront = sentence.replaceFirst(
          RegExp('\\b${RegExp.escape(targetWord)}\\b'),
          '[...]',
        );
        if (RegExp('\\b${RegExp.escape(targetWord)}\\b').hasMatch(clozeFront)) {
          continue;
        }
        cards.add(_card(
          id: 'cloze_${DateTime.now().microsecondsSinceEpoch}_${cards.length}',
          front: clozeFront,
          back: targetWord,
          type: CardType.cloze,
          source: source,
        ));
      }
    }

    if (cards.isEmpty) {
      final fallbackMatches = sentencePattern.allMatches(clean).take(3);
      for (final match in fallbackMatches) {
        final sentence = match.group(0)?.trim() ?? '';
        if (sentence.length > 20 &&
            !_isCodeSentence(sentence) &&
            !_isNoise(sentence)) {
          cards.add(_card(
            id: 'fb_${DateTime.now().microsecondsSinceEpoch}_${cards.length}',
            front: 'Recall the concept: $sentence',
            back: sentence,
            type: CardType.standard,
            source: source,
          ));
        }
      }
    }

    if (maxCards != null && cards.length > maxCards) {
      return cards.take(maxCards).toList();
    }
    return cards;
  }

  static (String, String)? _explicitPair(String line) {
    final questionAnswer = RegExp(
      r'^Q\s*:\s*(.+?)\s+A\s*:\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (questionAnswer != null) {
      return (questionAnswer.group(1)!.trim(), questionAnswer.group(2)!.trim());
    }
    for (final separator in ['::', '->']) {
      final parts = line.split(separator);
      if (parts.length == 2 &&
          parts.first.trim().isNotEmpty &&
          parts.last.trim().isNotEmpty) {
        return (parts.first.trim(), parts.last.trim());
      }
    }
    return null;
  }

  static List<Flashcard> generate(
    String rawText, {
    int maxCards = 25,
    String source = '',
  }) =>
      generateCards(rawText, source: source, maxCards: maxCards);

  static Flashcard _card({
    required String id,
    required String front,
    required String back,
    required CardType type,
    required String source,
  }) =>
      Flashcard(
        id: id,
        front: front,
        back: back,
        type: type,
        source: source,
      );

  static bool isReviewable(Flashcard card) {
    final answer = card.back.trim();
    if (answer.isEmpty || _stopWords.contains(answer.toLowerCase())) {
      return false;
    }
    if (RegExp(r'^[A-Z]{2,}[A-Z][a-z]').hasMatch(answer)) return false;
    if (card.type != CardType.cloze && card.front.contains('[...]')) {
      return false;
    }
    if (card.type != CardType.cloze) return true;
    if (!card.front.contains('[...]') || !card.front.endsWith('.')) {
      return false;
    }
    if (RegExp('\\b${RegExp.escape(answer)}\\b').hasMatch(card.front)) {
      return false;
    }
    if (RegExp('\\b${RegExp.escape(answer)}s\\b').hasMatch(card.front)) {
      return false;
    }
    return true;
  }

  static String? _bulletQuestion(String prefix) {
    final cleanPrefix = prefix.trim();
    final usedFor = RegExp(
      r'^(.+?)\s+is\s+used\s+for\s+the\s+following$',
      caseSensitive: false,
    ).firstMatch(cleanPrefix);
    if (usedFor != null) {
      return 'What is ${usedFor.group(1)!.trim()} used for?';
    }
    if (cleanPrefix.split(RegExp(r'\s+')).length > 12) return null;
    return 'What is $cleanPrefix?';
  }

  static bool _isCodeSentence(String sentence) {
    final value = sentence.trim();
    if (RegExp(
      r'^(import|package|public\s+class|private\s+|protected\s+|class\s+|return\b)',
      caseSensitive: false,
    ).hasMatch(value)) {
      return true;
    }
    if (RegExp(
            r'[{};]|\bnew\s+[A-Z]\w*\s*\(|\w+\.(set|add|addActionListener|setVisible|setBounds)\s*\(')
        .hasMatch(value)) {
      return true;
    }
    return RegExp(
                r'\b(public|private|protected|static|void|implements|extends)\b')
            .allMatches(value)
            .length >=
        2;
  }

  static bool _isNoise(String sentence) {
    final lower = sentence.toLowerCase();
    return lower.contains('table of contents') ||
        lower.contains('page ') ||
        lower.contains('chapter ');
  }

  static String _removeRepeatedHeading(String sentence) {
    final match = RegExp(
      r'^([A-Z][A-Za-z0-9_-]{2,30})\s+\1\s+',
    ).firstMatch(sentence);
    if (match != null) {
      return sentence.substring(match.group(1)!.length + 1);
    }
    final plural = RegExp(
      r'^([A-Z][A-Za-z0-9_-]{2,30})\s+([A-Z][A-Za-z0-9_-]{3,30}s)\s+',
    ).firstMatch(sentence);
    if (plural != null &&
        plural.group(2)!.toLowerCase() ==
            '${plural.group(1)!.toLowerCase()}s') {
      return sentence.substring(plural.group(1)!.length + 1);
    }
    return sentence;
  }
}
