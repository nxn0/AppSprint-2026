import 'dart:convert';

class Flashcard {
  const Flashcard(
      {required this.front, required this.back, this.isMastered = false});

  final String front;
  final String back;
  final bool isMastered;

  Flashcard copyWith({bool? isMastered}) => Flashcard(
        front: front,
        back: back,
        isMastered: isMastered ?? this.isMastered,
      );

  Map<String, dynamic> toJson() =>
      {'front': front, 'back': back, 'mastered': isMastered};

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        front: json['front'] as String? ?? '',
        back: json['back'] as String? ?? '',
        isMastered: json['mastered'] as bool? ?? false,
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

String encodeCards(List<Flashcard> cards) =>
    jsonEncode(cards.map((card) => card.toJson()).toList());
List<Flashcard> decodeCards(String? raw) => raw == null
    ? <Flashcard>[]
    : (jsonDecode(raw) as List<dynamic>)
        .map((item) => Flashcard.fromJson(item as Map<String, dynamic>))
        .toList();

String encodeDays(List<StudyDay> days) =>
    jsonEncode(days.map((day) => day.toJson()).toList());
List<StudyDay> decodeDays(String? raw) => raw == null
    ? <StudyDay>[]
    : (jsonDecode(raw) as List<dynamic>)
        .map((item) => StudyDay.fromJson(item as Map<String, dynamic>))
        .toList();
