import 'dart:convert';

class Flashcard {
  const Flashcard(
      {required this.front,
      required this.back,
      this.isMastered = false,
      this.tags = const [],
      this.source = '',
      this.confidence = 0.5,
      this.needsSource = false});

  final String front;
  final String back;
  final bool isMastered;
  final List<String> tags;
  final String source;
  final double confidence;
  final bool needsSource;

  Flashcard copyWith({bool? isMastered}) => Flashcard(
        front: front,
        back: back,
        isMastered: isMastered ?? this.isMastered,
        tags: tags,
        source: source,
        confidence: confidence,
        needsSource: needsSource,
      );

  Map<String, dynamic> toJson() => {
        'front': front,
        'back': back,
        'mastered': isMastered,
        'tags': tags,
        'source': source,
        'confidence': confidence,
        'needsSource': needsSource,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        front: json['front'] as String? ?? '',
        back: json['back'] as String? ?? '',
        isMastered: json['mastered'] as bool? ?? false,
        tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
        source: json['source'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
        needsSource: json['needsSource'] as bool? ?? false,
      );
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
  const StudyDay({required this.date, this.minutes = 0, this.restReason});

  final DateTime date;
  final int minutes;
  final String? restReason;

  bool get isRest => restReason != null;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'minutes': minutes,
        'restReason': restReason,
      };

  factory StudyDay.fromJson(Map<String, dynamic> json) => StudyDay(
        date: DateTime.parse(json['date'] as String),
        minutes: json['minutes'] as int? ?? 0,
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
