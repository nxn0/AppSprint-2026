import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class LocalStore {
  LocalStore(this._preferences);
  final SharedPreferences _preferences;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  String? get moniker => _preferences.getString('moniker');
  Future<void> saveMoniker(String value) => _preferences.setString('moniker', value);

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

  int get focusMinutes => _preferences.getInt('focusMinutes') ?? 25;
  Future<void> saveFocusMinutes(int value) =>
      _preferences.setInt('focusMinutes', value);

  int get breakMinutes => _preferences.getInt('breakMinutes') ?? 5;
  Future<void> saveBreakMinutes(int value) =>
      _preferences.setInt('breakMinutes', value);

  int get weeklyMinutesGoal => _preferences.getInt('weeklyMinutesGoal') ?? 300;
  Future<void> saveWeeklyMinutesGoal(int value) =>
      _preferences.setInt('weeklyMinutesGoal', value);

  int get weeklyTodoGoal => _preferences.getInt('weeklyTodoGoal') ?? 5;
  Future<void> saveWeeklyTodoGoal(int value) =>
      _preferences.setInt('weeklyTodoGoal', value);

  int get restAllowance => _preferences.getInt('restAllowance') ?? 3;
  Future<void> saveRestAllowance(int value) =>
      _preferences.setInt('restAllowance', value);

    DateTime? get lastRestCheck {
        final value = _preferences.getString('lastRestCheck');
        return value == null ? null : DateTime.tryParse(value);
    }

    Future<void> saveLastRestCheck(DateTime value) =>
            _preferences.setString('lastRestCheck', value.toIso8601String());
}
