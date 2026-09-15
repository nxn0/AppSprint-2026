import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class LocalStore {
  LocalStore(this._preferences);
  final SharedPreferences _preferences;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  String? get moniker => _preferences.getString('moniker');
  Future<void> saveMoniker(String value) =>
      _preferences.setString('moniker', value);
  List<Flashcard> get cards => decodeCards(_preferences.getString('cards'));
  Future<void> saveCards(List<Flashcard> value) =>
      _preferences.setString('cards', encodeCards(value));
  List<FlashcardDeck> get decks => decodeDecks(_preferences.getString('decks'));
  Future<void> saveDecks(List<FlashcardDeck> value) =>
      _preferences.setString('decks', encodeDecks(value));
  List<StudyDay> get days => decodeDays(_preferences.getString('days'));
  Future<void> saveDays(List<StudyDay> value) =>
      _preferences.setString('days', encodeDays(value));
    List<TodoItem> get todos => decodeTodos(_preferences.getString('todos'));
    Future<void> saveTodos(List<TodoItem> value) =>
      _preferences.setString('todos', encodeTodos(value));

  int get completedSessions => _preferences.getInt('completedSessions') ?? 0;
  Future<void> saveCompletedSessions(int value) =>
      _preferences.setInt('completedSessions', value);

  int get totalFocusMinutes => _preferences.getInt('totalFocusMinutes') ?? 0;
  Future<void> saveTotalFocusMinutes(int value) =>
      _preferences.setInt('totalFocusMinutes', value);
}

/// Conservative local parser primitives ported from the supplied regex registry.
/// Regexes only propose candidates; validators decide whether a card is usable.
class LocalRegexRegistry {
  static final pageNumberLine = RegExp(r'^\s*(?:Page\s*)?\d{1,3}\s*$',
      multiLine: true, caseSensitive: false);
  static final definition = RegExp(
      r'^\s*(?<term>[A-Z][\w+#.()/-]*(?:\s+[A-Z][\w+#.()/-]*){0,7})\s+(?<verb>is|are|refers\s+to|means|denotes|describes|is\s+known\s+as|can\s+be\s+defined\s+as)\s+(?<def>.{20,400}[.!?])\s*$',
      caseSensitive: false);
  static final colonDefinition = RegExp(
      r'^\s*(?<term>[A-Z][\w+#.()/-]*(?:\s+[A-Z][\w+#.()/-]*){0,7})\s*:\s*(?<def>.{20,400})\s*$',
      caseSensitive: false);
  static final bullet = RegExp(r'^\s*(?:o|[•▪·●*\-])\s+(?<text>.{3,})$');
  static final exampleMarker = RegExp(
      r'^\s*(?:Example|Eg|E\.g\.|For\s+example)\s*\d*\s*[:.\-]?\s*$',
      caseSensitive: false);
  static final codeLine = RegExp(
      r'^(?:import\s+|package\s+|public\s+(?:class|static)|private\s+|protected\s+|class\s+\w+\s*[\{:]|//|/\*|\*|\})',
      caseSensitive: false);

  static String normalize(String raw) => raw
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .replaceAll('\uFB01', 'fi')
      .replaceAll('\uFB02', 'fl')
      .replaceAll('\uFB00', 'ff')
      .replaceAll(RegExp(r'[\u2018\u2019\u201B]'), "'")
      .replaceAll(RegExp(r'[\u201C\u201D]'), '"')
      .replaceAll(RegExp(r'[\u2012\u2013\u2014\u2015]'), '-')
      .replaceAll(RegExp(r'[\u00A0\u2007\u202F]'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(pageNumberLine, '')
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .join('\n');

  static int codeScore(String line) {
    var score = 0;
    if (RegExp(r'[;{}]').hasMatch(line)) {
      score++;
    }
    if (RegExp(
            r'\b(class|interface|void|static|public|private|protected|abstract|final|extends|implements|import|package|new|return)\b')
        .hasMatch(line)) {
      score++;
    }
    if (RegExp(r'\w+\s*\([^)]*\)').hasMatch(line)) {
      score++;
    }
    if (RegExp(r'^\s{2,}').hasMatch(line)) {
      score++;
    }
    if (RegExp(r'System\.out\.print').hasMatch(line)) {
      score += 2;
    }
    if (RegExp(r'^[A-Z][a-z].*[a-z]\.\s*$').hasMatch(line)) {
      score -= 2;
    }
    return score;
  }

  static bool isCode(String line) =>
      codeLine.hasMatch(line.trim()) || codeScore(line) >= 2;

  static bool validTerm(String term) {
    final value = term.trim();
    if (value.length < 3 || value.split(RegExp(r'\s+')).length > 8) {
      return false;
    }
    return !RegExp(
      r'^(q|question|answer|this|that|it|there|they|these|those|when|where|what|who|why|how|the following|as|in|example|sample)\b',
      caseSensitive: false,
    ).hasMatch(value);
  }
}

class StudyFact {
  const StudyFact(this.term, this.body, this.source, this.line,
      {this.type = 'definition'});
  final String term;
  final String body;
  final String source;
  final int line;
  final String type;
}

/// A source-backed index. It deliberately returns null when the notes do not
/// contain an answer; callers can place that card in review instead of
/// fabricating a response.
class StudyKnowledgeIndex {
  final Map<String, StudyFact> definitions = {};
  final Map<String, List<String>> lists = {};
  final Map<String, String> acronyms = {};

  void addNotes(String raw, String source) {
    final lines = LocalRegexRegistry.normalize(raw).split('\n');
    var heading = '';
    var bullets = <String>[];
    void flushBullets() {
      if (heading.isNotEmpty && bullets.length >= 2) {
        lists[_key(heading)] = List<String>.from(bullets);
      }
      bullets = [];
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (LocalRegexRegistry.isCode(line) ||
          LocalRegexRegistry.exampleMarker.hasMatch(line)) {
        continue;
      }
      final bullet = LocalRegexRegistry.bullet.firstMatch(line);
      if (bullet != null) {
        bullets.add(bullet.namedGroup('text')!.trim());
        continue;
      }
      if (bullets.isNotEmpty) flushBullets();

      if (_isHeading(line)) {
        heading = line.replaceFirst(RegExp(r':\s*$'), '').trim();
        continue;
      }
      final definition = LocalRegexRegistry.definition.firstMatch(line) ??
          LocalRegexRegistry.colonDefinition.firstMatch(line);
      if (definition != null) {
        final term = definition.namedGroup('term')!.trim();
        final body = definition.namedGroup('def')!.trim();
        if (LocalRegexRegistry.validTerm(term)) {
          definitions.putIfAbsent(
              _key(term), () => StudyFact(term, body, source, i));
        }
      } else if (heading.isNotEmpty && line.length >= 45) {
        definitions.putIfAbsent(
            _key(heading), () => StudyFact(heading, line, source, i));
        heading = '';
      }
      for (final match in RegExp(
              r'\b(?<abbr>[A-Z][A-Z0-9]{1,7})\s*\((?<full>[A-Z][A-Za-z]+(?:\s+[A-Za-z]+){1,6})\)')
          .allMatches(line)) {
        acronyms[match.namedGroup('abbr')!] = match.namedGroup('full')!.trim();
      }
    }
    flushBullets();
  }

  StudyFact? define(String subject, {double threshold = .55}) {
    final wanted = _key(subject);
    if (wanted.isEmpty) return null;
    final exact = definitions[wanted];
    if (exact != null) return exact;
    StudyFact? best;
    var score = threshold;
    for (final entry in definitions.entries) {
      final overlap = _overlap(wanted, entry.key);
      if (overlap > score) {
        score = overlap;
        best = entry.value;
      }
    }
    return best;
  }

  List<String>? enumerate(String subject, {String? facet}) {
    final wanted = _key('${facet ?? ''} $subject');
    var score = .5;
    List<String>? best;
    for (final entry in lists.entries) {
      final value = _overlap(wanted, entry.key);
      if (value > score) {
        score = value;
        best = entry.value;
      }
    }
    return best;
  }

  String? expand(String value) =>
      acronyms[value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase()];

  static bool _isHeading(String line) =>
      line.length >= 3 &&
      line.length <= 70 &&
      !line.contains(RegExp(r'[.!?]')) &&
      (RegExp(r'^[A-Z][A-Z0-9 ,&()/_-]{3,}$').hasMatch(line) ||
          RegExp(r'^(swing|container|component|event|listener|jframe|jpanel|jlabel|jbutton)$',
                  caseSensitive: false)
              .hasMatch(line));

  static String _key(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) =>
          word.isNotEmpty &&
          !{'the', 'a', 'an', 'of', 'in', 'to', 'and', 'its'}.contains(word))
      .join(' ');

  static double _overlap(String left, String right) {
    final a = _key(left).split(' ').toSet();
    final b = _key(right).split(' ').toSet();
    if (a.isEmpty || b.isEmpty) return 0;
    return a.intersection(b).length / a.union(b).length;
  }
}

enum StudyAsk {
  definition,
  explanation,
  enumeration,
  comparison,
  expansion,
  open
}

class StudyIntent {
  const StudyIntent(this.ask, this.subject,
      {this.facet, this.terms = const []});
  final StudyAsk ask;
  final String subject;
  final String? facet;
  final List<String> terms;
}

class StudyIntentParser {
  static StudyIntent parse(String raw) {
    var text = raw.trim().replaceAll(RegExp(r'[.!?]+$'), '');
    final rules = <(RegExp, StudyAsk)>[
      (
        RegExp(r'^write\s+the\s+expansion\s+of\s+', caseSensitive: false),
        StudyAsk.expansion
      ),
      (
        RegExp(r'^(?:define|what\s+is(?:\s+meant\s+by)?)\s+',
            caseSensitive: false),
        StudyAsk.definition
      ),
      (
        RegExp(r'^(?:explain|describe|discuss)\s+', caseSensitive: false),
        StudyAsk.explanation
      ),
      (
        RegExp(r'^(?:list|name|mention)\s+', caseSensitive: false),
        StudyAsk.enumeration
      ),
      (
        RegExp(r'^(?:compare|differentiate|distinguish)\s+',
            caseSensitive: false),
        StudyAsk.comparison
      ),
    ];
    var ask = StudyAsk.open;
    for (final rule in rules) {
      if (rule.$1.hasMatch(text)) {
        ask = rule.$2;
        text = text.replaceFirst(rule.$1, '').trim();
        break;
      }
    }
    text = text
        .replaceFirst(
            RegExp(r'^(?:the|a|an|idea\s+of|concept\s+of)\s+',
                caseSensitive: false),
            '')
        .trim();
    String? facet;
    final facetMatch = RegExp(r'^(.{3,40}?)\s+of\s+(.+)$', caseSensitive: false)
        .firstMatch(text);
    if (facetMatch != null &&
        (ask == StudyAsk.enumeration || ask == StudyAsk.open)) {
      facet = facetMatch.group(1)!.trim();
      text = facetMatch.group(2)!.trim();
    }
    final terms = ask == StudyAsk.comparison
        ? text
            .split(RegExp(r'\s+(?:and|vs\.?|versus)\s+|\s*,\s*',
                caseSensitive: false))
            .map((item) => item.trim())
            .where((item) => item.length > 1)
            .toList()
        : const <String>[];
    return StudyIntent(ask, text, facet: facet, terms: terms);
  }
}

class StudyAnswerSynth {
  const StudyAnswerSynth(this.index);
  final StudyKnowledgeIndex index;

  Flashcard build(StudyIntent intent, String source) {
    final tags = [intent.ask.name];
    if (intent.ask == StudyAsk.expansion) {
      final abbr =
          intent.subject.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      final answer = index.expand(abbr);
      return Flashcard(
          front: 'What does $abbr stand for?',
          back: answer ?? '',
          tags: [...tags, 'acronym'],
          source: source,
          confidence: answer == null ? .25 : .95,
          needsSource: answer == null);
    }
    if (intent.ask == StudyAsk.comparison && intent.terms.length >= 2) {
      final backs = intent.terms
          .map(index.define)
          .whereType<StudyFact>()
          .map((fact) => '${fact.term}: ${fact.body}')
          .toList();
      return Flashcard(
          front: 'Compare ${intent.terms.join(' and ')}.',
          back: backs.join('\n'),
          tags: [...tags, 'compare'],
          source: source,
          confidence: backs.length == intent.terms.length ? .85 : .3,
          needsSource: backs.length != intent.terms.length);
    }
    final fact = index.define(intent.subject);
    final list = intent.ask == StudyAsk.enumeration
        ? index.enumerate(intent.subject, facet: intent.facet)
        : null;
    final answer = [
      if (fact != null) '${fact.term} ${fact.body}',
      if (list != null) ...list.map((item) => '• $item')
    ].join('\n');
    final front = switch (intent.ask) {
      StudyAsk.explanation => 'Explain ${intent.subject}.',
      StudyAsk.enumeration =>
        'List ${intent.facet ?? 'the points'} of ${intent.subject}.',
      _ => 'What is ${intent.subject}?',
    };
    return Flashcard(
        front: front,
        back: answer,
        tags: tags,
        source: source,
        confidence: answer.isEmpty ? .25 : .85,
        needsSource: answer.isEmpty);
  }
}

class FlashcardParser {
  static List<Flashcard> parse(String notes,
      {int maxCards = 30, String source = ''}) {
    maxCards = maxCards.clamp(30, 70);
    notes = LocalRegexRegistry.normalize(notes);
    final cards = <Flashcard>[];
    final patterns = <RegExp>[
      RegExp(r'Q:\s*(.*?)\s*A:\s*([^\n]+)',
          multiLine: true, caseSensitive: false),
      RegExp(r'^\s*(.*?)\s*::\s*(.*?)\s*$', multiLine: true),
      RegExp(r'^\s*-\s*\[\s?\]\s*(.*?)\s*->\s*(.*?)\s*$', multiLine: true),
    ];
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(notes)) {
        final front = match.group(1)?.trim() ?? '';
        final back = match.group(2)?.trim() ?? '';
        if (front.isNotEmpty && back.isNotEmpty) {
          cards.add(Flashcard(front: front, back: back));
        }
      }
    }
    cards.addAll(_parseDefinitionStatements(notes));
    cards.addAll(_parseRegistryDefinitions(notes));
    cards.addAll(_parsePromptBlocks(notes));
    cards.addAll(_parseHeadingBlocks(notes));
    cards.addAll(_parseDefinitionSentences(notes));
    cards.addAll(_parseSourceBackedPrompts(notes, source));
    final unique = <String, Flashcard>{};
    for (final card in cards) {
      final key = _normaliseKey(card.front);
      if (key.isNotEmpty && !unique.containsKey(key)) {
        unique[key] = card;
      }
    }
    final result = unique.values
        .map((card) => source.isEmpty || card.source.isNotEmpty
            ? card
            : Flashcard(
                front: card.front,
                back: card.back,
                tags: card.tags,
                source: source,
                confidence: card.confidence,
                needsSource: card.needsSource,
              ))
        .where((card) => !card.needsSource && card.back.trim().isNotEmpty)
        .toList();
    return result.length > maxCards ? result.sublist(0, maxCards) : result;
  }

  static List<Flashcard> _parseSourceBackedPrompts(
      String notes, String source) {
    if (source.isEmpty) return const [];
    final index = StudyKnowledgeIndex()..addNotes(notes, source);
    final synth = StudyAnswerSynth(index);
    final cards = <Flashcard>[];
    for (final line in _lines(notes)) {
      if (!RegExp(
              r'^(?:define|what\s+is|explain|describe|discuss|list|name|mention|compare|differentiate|distinguish|write\s+the\s+expansion)\b',
              caseSensitive: false)
          .hasMatch(line)) {
        continue;
      }
      final card = synth.build(StudyIntentParser.parse(line), source);
      if (!card.needsSource && card.back.isNotEmpty) cards.add(card);
    }
    return cards;
  }

  static List<Flashcard> _parseRegistryDefinitions(String notes) {
    final cards = <Flashcard>[];
    for (final line in _lines(notes)) {
      if (_isStructuredCard(line) ||
          LocalRegexRegistry.isCode(line) ||
          LocalRegexRegistry.exampleMarker.hasMatch(line)) {
        continue;
      }
      final match = LocalRegexRegistry.definition.firstMatch(line) ??
          LocalRegexRegistry.colonDefinition.firstMatch(line);
      if (match == null) continue;
      final term = _cleanSubject(match.namedGroup('term') ?? '');
      final definition = (match.namedGroup('def') ?? '').trim();
      if (!LocalRegexRegistry.validTerm(term) || definition.length < 20) {
        continue;
      }
      cards.add(Flashcard(
          front: 'What is $term?',
          back: _joinDefinitionContinuation(definition, notes, line)));
    }
    return cards;
  }

  static String _joinDefinitionContinuation(
      String definition, String notes, String sourceLine) {
    final lines = _lines(notes);
    final index = lines.indexOf(sourceLine);
    if (index < 0) return definition;
    final parts = <String>[definition];
    for (var next = index + 1;
        next < lines.length && parts.length < 8;
        next++) {
      final line = lines[next];
      if (line.isEmpty) continue;
      if (LocalRegexRegistry.isCode(line) ||
          LocalRegexRegistry.definition.hasMatch(line) ||
          LocalRegexRegistry.colonDefinition.hasMatch(line) ||
          _looksLikeHeading(line)) {
        break;
      }
      if (LocalRegexRegistry.bullet.hasMatch(line) || line.length >= 30) {
        parts.add(line);
      }
    }
    return parts.join(' ');
  }

  static String _normaliseKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static List<Flashcard> _parseDefinitionStatements(String notes) {
    final lines = notes
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .toList();
    final cards = <Flashcard>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.isEmpty || _isStructuredCard(line) || _isExampleLine(line)) {
        continue;
      }

      final match = _parseDefinitionLine(line);
      if (match == null) continue;

      final subject = _cleanSubject(match.group(1) ?? '');
      final firstAnswer = (match.group(2) ?? '').trim();
      if (!_isValidSubject(subject) || firstAnswer.length < 20) continue;

      final answerLines = <String>[firstAnswer];
      for (var next = index + 1;
          next < lines.length && answerLines.length < 8;
          next++) {
        final continuation = lines[next];
        if (_isExampleLine(continuation) ||
            _isNextConcept(continuation) ||
            _parseDefinitionLine(continuation) != null) {
          break;
        }
        if (continuation.isEmpty) continue;
        answerLines.add(continuation);
      }
      cards.add(Flashcard(
        front: 'What is $subject?',
        back: answerLines.join(' '),
      ));
    }
    return cards;
  }

  static RegExpMatch? _parseDefinitionLine(String line) {
    final prose = RegExp(
      r'^((?:[A-Z][A-Za-z0-9+#.()/_-]*\s*){1,6})\s+(?:(?:is|are)\s+(?:defined\s+as|known\s+as|described\s+as)|(?:refers\s+to|means|denotes|describes))\s+(.{20,})$',
      caseSensitive: false,
    );
    final colon = RegExp(
      r'^([A-Z][A-Za-z0-9+#.()/_-]*(?:\s+[A-Za-z][A-Za-z0-9+#.()/_-]*){0,6}):\s+(.{20,})$',
      caseSensitive: false,
    );
    final match = prose.firstMatch(line) ?? colon.firstMatch(line);
    if (match == null || (match.group(2)?.trim().length ?? 0) < 20) {
      return null;
    }
    return match;
  }

  static String _cleanSubject(String subject) => subject
      .replaceFirst(RegExp(r'^(the|a|an)\s+', caseSensitive: false), '')
      .trim();

  static bool _isValidSubject(String subject) =>
      subject.length >= 2 &&
      !subject.contains('?') &&
      subject.split(RegExp(r'\s+')).length <= 7 &&
      !RegExp(r'^(when|where|what|who|why|how|which|there|example|sample)\b',
              caseSensitive: false)
          .hasMatch(subject) &&
      !RegExp(r'^(q|question|answer)\s*:', caseSensitive: false)
          .hasMatch(subject);

  static bool _isStructuredCard(String line) =>
      RegExp(r'^(q\s*:|.*\s::\s|.*->)', caseSensitive: false).hasMatch(line);

  static List<Flashcard> _parsePromptBlocks(String notes) {
    final lines = notes
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .toList();
    final cards = <Flashcard>[];
    for (var index = 0; index < lines.length; index++) {
      final prompt = lines[index];
      if (!_looksLikePrompt(prompt)) continue;

      final inlineQuestion = prompt.indexOf('?');
      final front = inlineQuestion >= 0
          ? prompt.substring(0, inlineQuestion + 1).trim()
          : prompt;
      final inlineAnswer = inlineQuestion >= 0
          ? prompt.substring(inlineQuestion + 1).trim()
          : '';
      final answerLines = <String>[];
      if (inlineAnswer.isNotEmpty) answerLines.add(inlineAnswer);
      for (var next = index + 1;
          next < lines.length && answerLines.length < 4;
          next++) {
        final line = lines[next];
        if (line.isEmpty) {
          if (answerLines.isNotEmpty) break;
          continue;
        }
        if (_isNextConcept(line)) break;
        answerLines.add(line);
      }
      final back = answerLines.join(' ').trim();
      if (front.length >= 8 && back.length >= 3) {
        cards.add(Flashcard(front: front, back: back));
      }
    }
    return cards;
  }

  static List<Flashcard> _parseHeadingBlocks(String notes) {
    final lines = _lines(notes);
    final cards = <Flashcard>[];
    for (var index = 0; index < lines.length - 1; index++) {
      final heading = lines[index];
      if (!_looksLikeHeading(heading) || _isExampleHeading(heading)) continue;
      final firstAnswerIndex = _nextContentIndex(lines, index + 1);
      if (firstAnswerIndex == -1 ||
          !_isPlausibleHeadingAnswer(heading, lines[firstAnswerIndex])) {
        continue;
      }
      final answerLines = <String>[];
      for (var next = firstAnswerIndex;
          next < lines.length && answerLines.length < 8;
          next++) {
        final line = lines[next];
        if (_isExampleLine(line) ||
            (_looksLikeHeading(line) && answerLines.isNotEmpty) ||
            _isNextConcept(line) ||
            (_parseDefinitionLine(line) != null && answerLines.isNotEmpty)) {
          break;
        }
        if (line.isEmpty) continue;
        answerLines.add(line);
      }
      final answer = answerLines.join(' ').trim();
      if (answer.length >= 35) {
        cards.add(Flashcard(front: 'What is $heading?', back: answer));
      }
    }
    return cards;
  }

  static List<Flashcard> _parseDefinitionSentences(String notes) {
    final cards = <Flashcard>[];
    for (final line in _lines(notes)) {
      if (_isStructuredCard(line) ||
          _looksLikeHeading(line) ||
          _isExampleLine(line)) {
        continue;
      }
      final match = RegExp(
        r'^((?:[A-Z][A-Za-z0-9+.#()/_-]*\s+){0,5}[A-Z][A-Za-z0-9+.#()/_-]*)\s+(?:is|are|provides|works|allows|represents|creates|contains|supports|enables)\s+(.{35,})$',
        caseSensitive: false,
      ).firstMatch(line);
      if (match == null) continue;
      final subject = _cleanSubject(match.group(1) ?? '');
      final answer = (match.group(2) ?? '').trim();
      if (_isValidSubject(subject) && answer.length >= 25) {
        cards.add(Flashcard(front: 'What is $subject?', back: answer));
      }
    }
    return cards;
  }

  static List<String> _lines(String notes) => notes
      .split(RegExp(r'\r?\n'))
      .map((line) => line
          .replaceAll(
              RegExp(r'<(?:PARSED TEXT|IMAGE)[^>]*>', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim())
      .where((line) => !RegExp(r'^(page|sr\.?\s*no\.?|<)', caseSensitive: false)
          .hasMatch(line))
      .toList();

  static int _nextContentIndex(List<String> lines, int start) {
    for (var index = start; index < lines.length; index++) {
      if (lines[index].isNotEmpty) return index;
    }
    return -1;
  }

  static bool _isPlausibleHeadingAnswer(String heading, String answer) {
    if (_isExampleLine(answer) || _looksLikeHeading(answer)) return false;
    final subject = _normaliseKey(heading);
    final answerKey = _normaliseKey(answer);
    if (subject.length >= 4 && answerKey.contains(subject)) return true;
    return RegExp(
      r'\b(?:is|are)\s+(?:a|an|the)|\b(?:refers|means|used|provides|allows|represents|creates|contains|supports|enables|works)\b',
      caseSensitive: false,
    ).hasMatch(answer);
  }

  static bool _isExampleHeading(String line) => RegExp(
        r'\b(example|sample|code|application development)\b',
        caseSensitive: false,
      ).hasMatch(line);

  static bool _isExampleLine(String line) => RegExp(
        r'^(example\s*:|simple .* example|import\s+|public\s+(class|static)|class\s+\w+\s*\{|[a-zA-Z]+\.(set|add|is|create|action)|//|/\*|\*|\})',
        caseSensitive: false,
      ).hasMatch(line.trim());

  static bool _isNextConcept(String line) =>
      _parseDefinitionLine(line) != null ||
      (_looksLikeHeading(line) && !_isExampleHeading(line)) ||
      (line.contains('?') && line.length >= 12);

  static bool _looksLikeHeading(String line) {
    if (line.length < 3 || line.length > 70) return false;
    if (line.contains(RegExp(r'[.!?;:]'))) return false;
    if (_isStructuredCard(line) ||
        _looksLikePrompt(line) ||
        _isExampleLine(line)) {
      return false;
    }
    if (RegExp(r'^\d+\s*$').hasMatch(line)) return false;
    final words = line.split(' ');
    return words.length <= 8 &&
        (words.every((word) =>
                RegExp(r'^[A-Z][A-Za-z0-9+.#()/_-]*$').hasMatch(word)) ||
            RegExp(r'^(swing|container|component|event|listener|jframe|jpanel|jlabel|jbutton)\b',
                    caseSensitive: false)
                .hasMatch(line));
  }

  static bool _looksLikePrompt(String line) {
    if (line.length < 8) return false;
    if (_isStructuredCard(line) || _parseDefinitionLine(line) != null) {
      return false;
    }
    if (line.contains('?')) return true;
    return RegExp(
      r'^(state|explain|justify|describe|define|compare|list|identify|discuss|summarize|distinguish)\s+(?:the\s+)?[A-Za-z][^.!?]{2,80}$',
      caseSensitive: false,
    ).hasMatch(line);
  }
}

class PdfTextExtractorService {
  static Future<String> extract(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }
}

class AdaptivePlan {
  static Duration largeBreak(
      {required int completedSessions, required int studyMinutes}) {
    final fatigueRatio = (studyMinutes / 240).clamp(0.0, 1.0);
    final base = 15 + (fatigueRatio * 15).round();
    return Duration(
        minutes:
            completedSessions > 0 && completedSessions % 5 == 0 ? base : 0);
  }
}
