import 'dart:async';
import 'dart:io';
import 'dart:math';
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
  List<StudyDay> get days => decodeDays(_preferences.getString('days'));
  Future<void> saveDays(List<StudyDay> value) =>
      _preferences.setString('days', encodeDays(value));

  int get completedSessions => _preferences.getInt('completedSessions') ?? 0;
  Future<void> saveCompletedSessions(int value) =>
      _preferences.setInt('completedSessions', value);

  int get totalFocusMinutes => _preferences.getInt('totalFocusMinutes') ?? 0;
  Future<void> saveTotalFocusMinutes(int value) =>
      _preferences.setInt('totalFocusMinutes', value);
}

class FlashcardParser {
  static List<Flashcard> parse(String notes, {int maxCards = 30}) {
    maxCards = maxCards.clamp(30, 70);
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
    cards.addAll(_parsePromptBlocks(notes));
    cards.addAll(_parseHeadingBlocks(notes));
    cards.addAll(_parseDefinitionSentences(notes));
    final unique = <String, Flashcard>{};
    for (final card in cards) {
      final key = _normaliseKey(card.front);
      if (key.isNotEmpty && !unique.containsKey(key)) {
        unique[key] = card;
      }
    }
    final result = unique.values.toList();
    return result.length > maxCards ? result.sublist(0, maxCards) : result;
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
      if (!_isValidSubject(subject) || firstAnswer.length < 3) continue;

      final answerLines = <String>[firstAnswer];
      for (var next = index + 1;
          next < lines.length && answerLines.length < 8;
          next++) {
        final continuation = lines[next];
        if (_isExampleLine(continuation) ||
            _looksLikeHeading(continuation) ||
            _looksLikePrompt(continuation) ||
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
      r'^(.{2,100}?)\s+(?:(?:is|are)\s+(?:defined\s+as|known\s+as|described\s+as)|(?:refers\s+to|means|denotes|describes))\s+(.{3,})$',
      caseSensitive: false,
    );
    final colon = RegExp(
      r'^([A-Za-z][A-Za-z0-9 ()/_-]{1,90}):\s+(.{3,})$',
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
        if (_looksLikePrompt(line)) break;
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
            _looksLikePrompt(line) ||
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
        r'^((?:[A-Z][A-Za-z0-9+.#()/_-]*\s+){0,8}[A-Z][A-Za-z0-9+.#()/_-]*)\s+(?:is|are|provides|works|allows|represents|creates|contains|supports|enables)\s+(.{25,})$',
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
    return line.contains('?') ||
        RegExp(
          r'^(what|who|why|when|where|which|how|state|explain|justify|describe|define|compare|list|identify|discuss|summarize|distinguish)\b',
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

class PresenceService {
  PresenceService() {
    unawaited(_start());
  }

  final _controller = StreamController<List<PresencePoint>>.broadcast();
  final Map<String, DateTime> _seen = {};
  final String _token =
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 31)}';
  RawDatagramSocket? _socket;
  Timer? _timer;
  List<PresencePoint> _peers = const [];

  Stream<List<PresencePoint>> get stream => _controller.stream;
  int get activeCount => _peers.length;

  Future<void> _start() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 40404,
          reuseAddress: true, reusePort: true);
      _socket!.broadcastEnabled = true;
      _socket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket!.receive();
        if (datagram == null) return;
        final payload = String.fromCharCodes(datagram.data);
        if (!payload.startsWith('pulse_mesh_v1|')) return;
        final token =
            payload.split('|').length > 1 ? payload.split('|')[1] : null;
        if (token == null || token == _token) return;
        _seen[token] = DateTime.now();
        _emitPeers();
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        final message = 'pulse_mesh_v1|$_token';
        _socket?.send(
            message.codeUnits, InternetAddress('255.255.255.255'), 40404);
        _seen.removeWhere((_, lastSeen) =>
            DateTime.now().difference(lastSeen) > const Duration(seconds: 6));
        _emitPeers();
      });
    } on SocketException {
      _emitPeers();
    }
  }

  void _emitPeers() {
    _peers = _seen.keys.map((token) {
      final hash =
          token.codeUnits.fold<int>(17, (value, item) => value * 31 + item);
      final angle = (hash % 628) / 100;
      final radius = .25 + ((hash.abs() % 70) / 100);
      return PresencePoint(cos(angle) * radius, sin(angle) * radius, .72);
    }).toList();
    if (!_controller.isClosed) _controller.add(_peers);
  }

  void dispose() {
    _timer?.cancel();
    _socket?.close();
    _controller.close();
  }
}

class PresencePoint {
  const PresencePoint(this.x, this.y, this.opacity);
  final double x;
  final double y;
  final double opacity;
}
