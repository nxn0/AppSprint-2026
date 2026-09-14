import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'services.dart';

class AppState extends ChangeNotifier {
  AppState(this.store);

  final LocalStore store;
  final PresenceService presence = PresenceService();
  String moniker = '';
  List<Flashcard> cards = [];
  List<StudyDay> days = [];
  bool isOnline = true;
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
    days = store.days;
    completedSessions = store.completedSessions;
    totalFocusMinutes = store.totalFocusMinutes;
    notifyListeners();
  }

  void toggleOnline() {
    isOnline = !isOnline;
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
                studyMinutes: totalFocusMinutes)
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
        minutes: (index == -1 ? 0 : days[index].minutes) + minutes);
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
      StudyDay(date: today, restReason: reason)
    ];
    await store.saveDays(days);
    notifyListeners();
  }

  Future<void> addCards(List<Flashcard> parsed) async {
    cards = [...cards, ...parsed];
    await store.saveCards(cards);
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
    presence.dispose();
    super.dispose();
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
