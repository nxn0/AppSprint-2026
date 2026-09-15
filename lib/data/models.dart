import 'dart:convert';
import 'dart:math';

enum CardType { standard, cloze }

class Flashcard {
  const Flashcard({
    required this.front,
    required this.back,
    this.isMastered = false,
    this.tags = const [],
    this.source = '',
    this.confidence = 0.5,
    this.needsSource = false,
    this.dueAt,
    this.intervalDays = 0,
    this.ease = 2.5,
    this.repetitions = 0,
    this.lapses = 0,
    this.lastReviewed,
    required this.id,
    this.type = CardType.standard,
  });

  final String id;
  final CardType type;

  final String front;
  final String back;
  final bool isMastered;
  final List<String> tags;
  final String source;
  final double confidence;
  final bool needsSource;
  final DateTime? dueAt;
  final int intervalDays;
  final double ease;
  final int repetitions;
  final int lapses;
  final DateTime? lastReviewed;

  Flashcard copyWith({
    String? front,
    String? back,
    bool? isMastered,
    DateTime? dueAt,
    int? intervalDays,
    double? ease,
    int? repetitions,
    int? lapses,
    DateTime? lastReviewed,
  }) =>
      Flashcard(
        id: id,
        front: front ?? this.front,
        back: back ?? this.back,
        type: type,
        isMastered: isMastered ?? this.isMastered,
        tags: tags,
        source: source,
        confidence: confidence,
        needsSource: needsSource,
        dueAt: dueAt ?? this.dueAt,
        intervalDays: intervalDays ?? this.intervalDays,
        ease: ease ?? this.ease,
        repetitions: repetitions ?? this.repetitions,
        lapses: lapses ?? this.lapses,
        lastReviewed: lastReviewed ?? this.lastReviewed,
      );

  Map<String, dynamic> toJson() => {
        'front': front,
        'back': back,
        'mastered': isMastered,
        'tags': tags,
        'source': source,
        'confidence': confidence,
        'needsSource': needsSource,
        'dueAt': dueAt?.toIso8601String(),
        'intervalDays': intervalDays,
        'ease': ease,
        'repetitions': repetitions,
        'lapses': lapses,
        'lastReviewed': lastReviewed?.toIso8601String(),
        'id': id,
        'type': type.name,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        front: json['front'] as String? ?? '',
        back: json['back'] as String? ?? '',
        isMastered: json['mastered'] as bool? ?? false,
        tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
        source: json['source'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
        needsSource: json['needsSource'] as bool? ?? false,
        dueAt: DateTime.tryParse(json['dueAt'] as String? ?? ''),
        intervalDays: json['intervalDays'] as int? ?? 0,
        ease: (json['ease'] as num?)?.toDouble() ?? 2.5,
        repetitions: json['repetitions'] as int? ?? 0,
        lapses: json['lapses'] as int? ?? 0,
        lastReviewed: DateTime.tryParse(json['lastReviewed'] as String? ?? ''),
        id: json['id'] as String? ??
            _stableCardId(
                json['front'] as String? ?? '', json['back'] as String? ?? ''),
        type: CardType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => CardType.standard,
        ),
      );
}

String _stableCardId(String front, String back) {
  var hash = 17;
  for (final codeUnit in '$front\u0000$back'.codeUnits) {
    hash = 37 * hash + codeUnit;
  }
  return 'card-${hash.abs()}';
}

enum ReviewRating { again, hard, good, easy }

extension FlashcardReview on Flashcard {
  bool isDue([DateTime? now]) =>
      dueAt == null || !dueAt!.isAfter(now ?? DateTime.now());

  Flashcard scheduled(ReviewRating rating, {DateTime? now}) {
    final reviewedAt = now ?? DateTime.now();
    var nextEase = ease;
    var nextRepetitions = repetitions;
    var nextLapses = lapses;
    var nextInterval = intervalDays;
    late DateTime nextDue;

    switch (rating) {
      case ReviewRating.again:
        nextEase = (ease - .2).clamp(1.3, 3.0).toDouble();
        nextRepetitions = 0;
        nextLapses++;
        nextInterval = 0;
        nextDue = reviewedAt.add(const Duration(minutes: 10));
      case ReviewRating.hard:
        nextEase = (ease - .15).clamp(1.3, 3.0).toDouble();
        nextRepetitions++;
        nextInterval =
            max(1, (intervalDays == 0 ? 1 : intervalDays * 1.2).round());
        nextDue = reviewedAt.add(Duration(days: nextInterval));
      case ReviewRating.good:
        nextRepetitions++;
        nextInterval = repetitions == 0
            ? 1
            : repetitions == 1
                ? 3
                : max(1, (intervalDays * ease).round());
        nextDue = reviewedAt.add(Duration(days: nextInterval));
      case ReviewRating.easy:
        nextEase = (ease + .15).clamp(1.3, 3.0).toDouble();
        nextRepetitions++;
        nextInterval = repetitions == 0
            ? 4
            : max(1, (intervalDays * nextEase * 1.3).round());
        nextDue = reviewedAt.add(Duration(days: nextInterval));
    }
    return copyWith(
      dueAt: nextDue,
      intervalDays: nextInterval,
      ease: nextEase,
      repetitions: nextRepetitions,
      lapses: nextLapses,
      lastReviewed: reviewedAt,
    );
  }
}

class FlashcardDeck {
  const FlashcardDeck({
    required this.id,
    required this.title,
    required this.cards,
    required this.createdAt,
    this.sourceName,
  });

  final String id;
  final String title;
  final List<Flashcard> cards;
  final DateTime createdAt;
  final String? sourceName;

  FlashcardDeck copyWith({String? title, List<Flashcard>? cards}) =>
      FlashcardDeck(
        id: id,
        title: title ?? this.title,
        cards: cards ?? this.cards,
        createdAt: createdAt,
        sourceName: sourceName,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cards': cards.map((card) => card.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'sourceName': sourceName,
      };

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) => FlashcardDeck(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled deck',
        cards: (json['cards'] as List<dynamic>? ?? [])
            .map((item) => Flashcard.fromJson(item as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        sourceName: json['sourceName'] as String?,
      );
}

class StudyDay {
  const StudyDay({
    required this.date,
    this.minutes = 0,
    this.reviews = 0,
    this.createdTodos = 0,
    this.completedTodos = 0,
    this.restReason,
  });

  final DateTime date;
  final int minutes;
  final int reviews;
  final int createdTodos;
  final int completedTodos;
  final String? restReason;

  bool get isRest => restReason != null;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'minutes': minutes,
        'reviews': reviews,
        'createdTodos': createdTodos,
        'completedTodos': completedTodos,
        'restReason': restReason,
      };

  factory StudyDay.fromJson(Map<String, dynamic> json) => StudyDay(
        date: DateTime.parse(json['date'] as String),
        minutes: json['minutes'] as int? ?? 0,
        reviews: json['reviews'] as int? ?? 0,
        createdTodos: json['createdTodos'] as int? ?? 0,
        completedTodos: json['completedTodos'] as int? ?? 0,
        restReason: json['restReason'] as String?,
      );
}

class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  final String id;
  final String title;
  final bool isDone;

  TodoItem copyWith({bool? isDone}) => TodoItem(
        id: id,
        title: title,
        isDone: isDone ?? this.isDone,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        isDone: json['isDone'] as bool? ?? false,
      );
}

String encodeCards(List<Flashcard> cards) =>
    jsonEncode(cards.map((card) => card.toJson()).toList());

List<Flashcard> decodeCards(String? raw) => raw == null
    ? <Flashcard>[]
    : (jsonDecode(raw) as List<dynamic>)
        .map((item) => Flashcard.fromJson(item as Map<String, dynamic>))
        .toList();

String encodeDecks(List<FlashcardDeck> decks) =>
    jsonEncode(decks.map((deck) => deck.toJson()).toList());

List<FlashcardDeck> decodeDecks(String? raw) => raw == null
    ? <FlashcardDeck>[]
    : (jsonDecode(raw) as List<dynamic>)
        .map((item) => FlashcardDeck.fromJson(item as Map<String, dynamic>))
        .toList();

String encodeDays(List<StudyDay> days) =>
    jsonEncode(days.map((day) => day.toJson()).toList());

List<StudyDay> decodeDays(String? raw) => raw == null
    ? <StudyDay>[]
    : (jsonDecode(raw) as List<dynamic>)
        .map((item) => StudyDay.fromJson(item as Map<String, dynamic>))
        .toList();

String encodeTodos(List<TodoItem> todos) =>
    jsonEncode(todos.map((todo) => todo.toJson()).toList());

List<TodoItem> decodeTodos(String? raw) => raw == null
    ? <TodoItem>[]
    : (jsonDecode(raw) as List<dynamic>)
        .map((item) => TodoItem.fromJson(item as Map<String, dynamic>))
        .toList();
