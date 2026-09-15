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
}
