import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../services/local_flashcard_engine.dart';

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
  int focusMinutes = 25;
  int breakMinutes = 5;
  int weeklyMinutesGoal = 300;
  int weeklyTodoGoal = 5;
  int restAllowance = 3;
  int completedSessions = 0;
  int totalFocusMinutes = 0;
  Timer? _timer;
  Timer? _restTimer;
  int _focusElapsedSeconds = 0;

  Future<void> initialize() async {
    final savedMoniker = store.moniker;
    moniker = savedMoniker == null || savedMoniker.startsWith('anon-')
        ? 'fellow homo sapien'
        : savedMoniker;
    await store.saveMoniker(moniker);
    cards = store.cards;
    decks = store.decks;
    final cleanedDecks = decks
        .map((deck) => deck.copyWith(
              cards:
                  deck.cards.where(LocalFlashcardEngine.isReviewable).toList(),
            ))
        .where((deck) => deck.cards.isNotEmpty)
        .toList();
    if (cleanedDecks.length != decks.length ||
        cleanedDecks.any((deck) =>
            deck.cards.length !=
            decks.firstWhere((item) => item.id == deck.id).cards.length)) {
      decks = cleanedDecks;
      await store.saveDecks(decks);
    }
    if (decks.isEmpty && cards.isNotEmpty) {
      final legacyCards =
          cards.where(LocalFlashcardEngine.isReviewable).toList();
      decks = [
        FlashcardDeck(
          id: 'legacy-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Imported cards',
          cards: legacyCards,
          createdAt: DateTime.now(),
          sourceName: 'Previous local cards',
        ),
      ];
      await store.saveDecks(decks);
    }
    selectedDeckId = decks.firstOrNull?.id;
    days = store.days;
    todos = store.todos;
    completedSessions = store.completedSessions >= 5
        ? 0
        : store.completedSessions.clamp(0, 4);
    if (store.completedSessions != completedSessions) {
      await store.saveCompletedSessions(completedSessions);
    }
    totalFocusMinutes = store.totalFocusMinutes;
    focusMinutes = store.focusMinutes;
    breakMinutes = store.breakMinutes;
    weeklyMinutesGoal = store.weeklyMinutesGoal;
    weeklyTodoGoal = store.weeklyTodoGoal;
    restAllowance = store.restAllowance.clamp(0, 3);
    await _reconcileRestAllowance();
    _restTimer ??= Timer.periodic(const Duration(minutes: 1), (_) async {
      await _reconcileRestAllowance();
      notifyListeners();
    });
    remaining = Duration(minutes: focusMinutes);
    final loggedMinutes = days.fold<int>(0, (sum, day) => sum + day.minutes);
    if (loggedMinutes > totalFocusMinutes) {
      totalFocusMinutes = loggedMinutes;
      await store.saveTotalFocusMinutes(totalFocusMinutes);
    }
    notifyListeners();
  }

  Future<void> updateMoniker(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    moniker = trimmed;
    notifyListeners();
    await store.saveMoniker(moniker);
  }

  int get streak {
    if (restAllowance == 0) return 0;
    final activeDates = days
        .where((day) =>
            day.minutes > 0 ||
            day.reviews > 0 ||
            day.createdTodos > 0 ||
            day.completedTodos > 0)
        .map((day) => _dateKey(day.date))
        .toSet();
    if (isRunning) activeDates.add(_dateKey(DateTime.now()));
    var cursor = DateTime.now();
    var count = 0;
    while (true) {
      final key = _dateKey(cursor);
      final day = days.where((item) => _dateKey(item.date) == key).firstOrNull;
      if (activeDates.contains(key)) {
        count++;
      } else if (day?.isRest == true) {
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      } else {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  int get todayFocusMinutes {
    final today = _dateKey(DateTime.now());
    final logged = days
        .where((day) => _dateKey(day.date) == today)
        .fold<int>(0, (sum, day) => sum + day.minutes);
    final timerMinutes = _focusElapsedSeconds ~/ 60;
    return logged > timerMinutes ? logged : timerMinutes;
  }

  Future<void> updateTimerSettings({
    required int focusMinutes,
    required int breakMinutes,
  }) async {
    this.focusMinutes = focusMinutes.clamp(1, 120);
    this.breakMinutes = breakMinutes.clamp(1, 60);
    if (!isRunning && !isBreak) {
      remaining = Duration(minutes: this.focusMinutes);
    }
    await store.saveFocusMinutes(this.focusMinutes);
    await store.saveBreakMinutes(this.breakMinutes);
    notifyListeners();
  }

  Future<void> updateWeeklyMinutesGoal(int value) async {
    weeklyMinutesGoal = value.clamp(1, 10080);
    await store.saveWeeklyMinutesGoal(weeklyMinutesGoal);
    notifyListeners();
  }

  Future<void> updateWeeklyTodoGoal(int value) async {
    weeklyTodoGoal = value.clamp(1, 10000);
    await store.saveWeeklyTodoGoal(weeklyTodoGoal);
    notifyListeners();
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
    if (!isBreak) {
      _focusElapsedSeconds++;
      if (_focusElapsedSeconds % 60 == 0) {
        totalFocusMinutes++;
        unawaited(logActivity(minutes: 1));
        unawaited(store.saveTotalFocusMinutes(totalFocusMinutes));
      }
    }
    if (remaining.inSeconds <= 1) {
      if (isBreak) {
        if (isLongBreak) {
          _timer?.cancel();
          isRunning = false;
          isBreak = false;
          isLongBreak = false;
          completedSessions = 0;
          unawaited(store.saveCompletedSessions(completedSessions));
          remaining = Duration(minutes: focusMinutes);
        } else {
          isBreak = false;
          remaining = Duration(minutes: focusMinutes);
        }
      } else {
        _completeFocusCycle();
      }
    } else {
      remaining -= const Duration(seconds: 1);
    }
    notifyListeners();
  }

  Future<void> skipTimer() async {
    final wasRunning = isRunning;
    var shouldResume = wasRunning;
    _timer?.cancel();
    isRunning = false;
    if (isBreak) {
      if (isLongBreak) {
        isBreak = false;
        isLongBreak = false;
        completedSessions = 0;
        await store.saveCompletedSessions(completedSessions);
        remaining = Duration(minutes: focusMinutes);
        shouldResume = false;
      } else {
        isBreak = false;
        remaining = Duration(minutes: focusMinutes);
      }
    } else {
      _completeFocusCycle();
    }
    if (shouldResume) {
      isRunning = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    notifyListeners();
  }

  void _completeFocusCycle() {
    completedSessions++;
    unawaited(store.saveCompletedSessions(completedSessions));
    _focusElapsedSeconds = 0;
    isBreak = true;
    isLongBreak = completedSessions == 5;
    remaining = Duration(
      minutes: isLongBreak ? breakMinutes * 5 : breakMinutes,
    );
  }

  Future<void> logRest(String reason) async {
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final alreadyResting =
        days.where((day) => _dateKey(day.date) == todayKey).firstOrNull?.isRest ??
            false;
    if (!alreadyResting && restAllowance > 0) {
      restAllowance--;
      await store.saveRestAllowance(restAllowance);
    }
    days = [
      ...days.where((day) => _dateKey(day.date) != todayKey),
      StudyDay(date: today, restReason: reason),
    ];
    await store.saveDays(days);
    notifyListeners();
  }

  Future<void> _reconcileRestAllowance() async {
    final today = _dayOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final storedCheck = store.lastRestCheck;
    var check = storedCheck == null
        ? yesterday
        : _dayOnly(storedCheck);
    if (check.isAfter(yesterday)) return;

    var cursor = check.add(const Duration(days: 1));
    while (!cursor.isAfter(yesterday)) {
      final key = _dateKey(cursor);
      final day = days.where((item) => _dateKey(item.date) == key).firstOrNull;
      final active = day != null &&
          (day.minutes > 0 ||
              day.reviews > 0 ||
              day.createdTodos > 0 ||
              day.completedTodos > 0);
      if (!active && day?.isRest != true && restAllowance > 0) {
        restAllowance--;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    await store.saveRestAllowance(restAllowance);
    await store.saveLastRestCheck(yesterday);
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
    notifyListeners();
    await logActivity(createdTodos: 1);
    await store.saveTodos(todos);
  }

  Future<void> toggleTodo(String todoId) async {
    final wasDone =
        todos.where((todo) => todo.id == todoId).firstOrNull?.isDone ?? false;
    todos = todos
        .map((todo) =>
            todo.id == todoId ? todo.copyWith(isDone: !todo.isDone) : todo)
        .toList();
    notifyListeners();
    await logActivity(completedTodos: wasDone ? -1 : 1);
    await store.saveTodos(todos);
  }

  Future<void> deleteTodo(String todoId) async {
    todos = todos.where((todo) => todo.id != todoId).toList();
    notifyListeners();
    await store.saveTodos(todos);
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

  List<int> get dueCardIndexes {
    final deck = selectedDeck;
    if (deck == null) return const [];
    final now = DateTime.now();
    return [
      for (var index = 0; index < deck.cards.length; index++)
        if (LocalFlashcardEngine.isReviewable(deck.cards[index]) &&
            !deck.cards[index].isMastered &&
            deck.cards[index].isDue(now))
          index,
    ];
  }

  Future<void> reviewDeckCard(int index, ReviewRating rating) async {
    final deck = selectedDeck;
    if (deck == null || index < 0 || index >= deck.cards.length) return;
    final updatedCards = [...deck.cards]..[index] =
        deck.cards[index].scheduled(rating);
    final updated = deck.copyWith(cards: updatedCards);
    decks = decks.map((item) => item.id == deck.id ? updated : item).toList();
    notifyListeners();
    await store.saveDecks(decks);
    await logActivity(reviews: 1);
  }

  Future<void> logActivity({
    int minutes = 0,
    int reviews = 0,
    int createdTodos = 0,
    int completedTodos = 0,
  }) async {
    if (minutes == 0 &&
        reviews == 0 &&
        createdTodos == 0 &&
        completedTodos == 0) {
      return;
    }
    final today = DateTime.now();
    final key = _dateKey(today);
    final studied = minutes > 0 || reviews > 0;
    if (studied && restAllowance != 3) {
      restAllowance = 3;
      await store.saveRestAllowance(restAllowance);
    }
    final index = days.indexWhere((day) => _dateKey(day.date) == key);
    final current = index == -1 ? StudyDay(date: today) : days[index];
    final updated = StudyDay(
      date: today,
      minutes: current.minutes + minutes,
      reviews: current.reviews + reviews,
      createdTodos: current.createdTodos + createdTodos,
      completedTodos: current.completedTodos + completedTodos,
    );
    days = index == -1 ? [...days, updated] : [...days]
      ..[index] = updated;
    notifyListeners();
    await store.saveDays(days);
  }

  Future<void> toggleDeckMastery(int index) async {
    final deck = selectedDeck;
    if (deck == null || index < 0 || index >= deck.cards.length) return;
    final updatedCards = [...deck.cards]..[index] = deck.cards[index].copyWith(
        isMastered: !deck.cards[index].isMastered,
      );
    final updated = deck.copyWith(cards: updatedCards);
    decks = decks.map((item) => item.id == deck.id ? updated : item).toList();
    notifyListeners();
    await store.saveDecks(decks);
  }

  Future<void> updateDeckCard({
    required String deckId,
    required String cardId,
    required String front,
    required String back,
  }) async {
    final deck = decks.where((item) => item.id == deckId).firstOrNull;
    if (deck == null || front.trim().isEmpty || back.trim().isEmpty) return;
    final updatedCards = deck.cards
        .map((card) => card.id == cardId
            ? card.copyWith(front: front.trim(), back: back.trim())
            : card)
        .toList();
    decks = decks
        .map((item) => item.id == deckId
            ? item.copyWith(cards: updatedCards)
            : item)
        .toList();
    notifyListeners();
    await store.saveDecks(decks);
  }

  Future<void> toggleMastery(int index) async {
    cards = [...cards]..[index] =
        cards[index].copyWith(isMastered: !cards[index].isMastered);
    await store.saveCards(cards);
    notifyListeners();
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
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
      minutes: completedSessions > 0 && completedSessions % 5 == 0 ? base : 0,
    );
  }
}
