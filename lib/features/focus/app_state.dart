import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/local_store.dart';
import '../../data/models.dart';

class AppState extends ChangeNotifier {
  AppState(this.store);

  final LocalStore store;
  String moniker = '';
  List<Flashcard> cards = [];
  List<FlashcardDeck> decks = [];
  String? selectedDeckId;
  List<StudyDay> days = [];
  List<TodoItem> todos = [];
  bool isRunning = false;
  bool isBreak = false;
  bool isLongBreak = false;
  Duration remaining = const Duration(minutes: 25);
  int completedSessions = 0;
  int totalFocusMinutes = 0;
  Timer? _timer;

  Future<void> initialize() async {
    moniker = store.moniker ?? _makeMoniker();
    await store.saveMoniker(moniker);
    cards = store.cards;
    decks = store.decks;
    if (decks.isEmpty && cards.isNotEmpty) {
      decks = [
        FlashcardDeck(
          id: 'legacy-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Imported cards',
          cards: cards,
          createdAt: DateTime.now(),
          sourceName: 'Previous local cards',
        ),
      ];
      await store.saveDecks(decks);
    }
    selectedDeckId = decks.firstOrNull?.id;
    days = store.days;
    todos = store.todos;
    completedSessions = store.completedSessions;
    totalFocusMinutes = store.totalFocusMinutes;
    notifyListeners();
  }

  String _makeMoniker() => 'anon-${1000 + Random().nextInt(8999)}';

  int get streak {
    final activeDates = days
        .where((day) => day.minutes > 0)
        .map((day) => _dateKey(day.date))
        .toSet();
    var cursor = DateTime.now();
    var count = 0;
    var idleDays = 0;
    while (idleDays < 3) {
      final key = _dateKey(cursor);
      final day = days.where((item) => _dateKey(item.date) == key).firstOrNull;
      if (activeDates.contains(key)) {
        count++;
        idleDays = 0;
      } else if (day?.isRest == true) {
        idleDays = 0;
      } else {
        idleDays++;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return idleDays >= 3 ? 0 : count;
  }

  Future<void> toggleTimer() async {
    if (isRunning) {
      _timer?.cancel();
      isRunning = false;
    } else {
      isRunning = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    notifyListeners();
  }

  void _tick() {
    if (remaining.inSeconds <= 1) {
      if (isBreak) {
        if (isLongBreak) {
          _timer?.cancel();
          isRunning = false;
          isBreak = false;
          isLongBreak = false;
          remaining = const Duration(minutes: 25);
        } else {
          isBreak = false;
          remaining = const Duration(minutes: 25);
        }
      } else {
        completedSessions++;
        totalFocusMinutes += 25;
        unawaited(_logStudy(25));
        unawaited(store.saveCompletedSessions(completedSessions));
        unawaited(store.saveTotalFocusMinutes(totalFocusMinutes));
        isBreak = true;
        isLongBreak = completedSessions % 5 == 0;
        remaining = isLongBreak
            ? AdaptivePlan.largeBreak(
                completedSessions: completedSessions,
                studyMinutes: totalFocusMinutes,
              )
            : const Duration(minutes: 5);
      }
    } else {
      remaining -= const Duration(seconds: 1);
    }
    notifyListeners();
  }

  Future<void> skipTimer() async {
    final wasRunning = isRunning;
    _timer?.cancel();
    isRunning = false;
    if (isBreak) {
      isBreak = false;
      isLongBreak = false;
      remaining = const Duration(minutes: 25);
    } else {
      isBreak = true;
      isLongBreak = false;
      remaining = const Duration(minutes: 5);
    }
    if (wasRunning) {
      isRunning = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    notifyListeners();
  }

  Future<void> _logStudy(int minutes) async {
    final today = DateTime.now();
    final index =
        days.indexWhere((day) => _dateKey(day.date) == _dateKey(today));
    final updated = StudyDay(
      date: today,
      minutes: (index == -1 ? 0 : days[index].minutes) + minutes,
    );
    if (index == -1) {
      days = [...days, updated];
    } else {
      days = [...days]..[index] = updated;
    }
    await store.saveDays(days);
  }

  Future<void> logRest(String reason) async {
    final today = DateTime.now();
    days = [
      ...days.where((day) => _dateKey(day.date) != _dateKey(today)),
      StudyDay(date: today, restReason: reason),
    ];
    await store.saveDays(days);
    notifyListeners();
  }

  Future<void> addCards(List<Flashcard> parsed) async {
    cards = [...cards, ...parsed];
    await store.saveCards(cards);
    notifyListeners();
  }

  Future<void> addTodo(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    todos = [
      ...todos,
      TodoItem(id: '${DateTime.now().microsecondsSinceEpoch}', title: trimmed),
    ];
    await store.saveTodos(todos);
    notifyListeners();
  }

  Future<void> toggleTodo(String todoId) async {
    todos = todos
        .map((todo) => todo.id == todoId
            ? todo.copyWith(isDone: !todo.isDone)
            : todo)
        .toList();
    await store.saveTodos(todos);
    notifyListeners();
  }

  Future<void> deleteTodo(String todoId) async {
    todos = todos.where((todo) => todo.id != todoId).toList();
    await store.saveTodos(todos);
    notifyListeners();
  }

  Future<void> addDeck({
    required String title,
    required List<Flashcard> parsed,
    String? sourceName,
  }) async {
    if (parsed.isEmpty) return;
    final deck = FlashcardDeck(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      cards: parsed,
      createdAt: DateTime.now(),
      sourceName: sourceName,
    );
    decks = [...decks, deck];
    selectedDeckId = deck.id;
    await store.saveDecks(decks);
    notifyListeners();
  }

  Future<void> deleteDeck(String deckId) async {
    decks = decks.where((deck) => deck.id != deckId).toList();
    if (selectedDeckId == deckId) {
      selectedDeckId = decks.firstOrNull?.id;
    }
    await store.saveDecks(decks);
    notifyListeners();
  }

  void selectDeck(String deckId) {
    selectedDeckId = deckId;
    notifyListeners();
  }

  FlashcardDeck? get selectedDeck =>
      decks.where((deck) => deck.id == selectedDeckId).firstOrNull;

  Future<void> toggleDeckMastery(int index) async {
    final deck = selectedDeck;
    if (deck == null || index < 0 || index >= deck.cards.length) return;
    final updatedCards = [...deck.cards]
      ..[index] = deck.cards[index].copyWith(
        isMastered: !deck.cards[index].isMastered,
      );
    final updated = deck.copyWith(cards: updatedCards);
    decks = decks.map((item) => item.id == deck.id ? updated : item).toList();
    await store.saveDecks(decks);
    notifyListeners();
  }

  Future<void> toggleMastery(int index) async {
    cards = [...cards]..[index] =
        cards[index].copyWith(isMastered: !cards[index].isMastered);
    await store.saveCards(cards);
    notifyListeners();
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class AdaptivePlan {
  static Duration largeBreak({
    required int completedSessions,
    required int studyMinutes,
  }) {
    final fatigueRatio = (studyMinutes / 240).clamp(0.0, 1.0);
    final base = 15 + (fatigueRatio * 15).round();
    return Duration(
      minutes:
          completedSessions > 0 && completedSessions % 5 == 0 ? base : 0,
    );
  }
}
