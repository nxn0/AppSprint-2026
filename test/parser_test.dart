import 'package:flutter_test/flutter_test.dart';
import 'package:pomly/services.dart';
import 'package:pomly/data/models.dart';

void main() {
  test('parses supported local flashcard formats', () {
    final cards = FlashcardParser.parse('''
Q: What is Dart? A: A client-optimized language.

async :: A modifier for asynchronous functions
- [ ] Flutter -> UI toolkit
''');

    expect(cards, hasLength(3));
    expect(cards.first.front, 'What is Dart?');
    expect(cards.last.back, 'UI toolkit');
  });

  test('scales the large break every fifth completed session', () {
    expect(
      AdaptivePlan.largeBreak(completedSessions: 4, studyMinutes: 120),
      Duration.zero,
    );
    expect(
      AdaptivePlan.largeBreak(completedSessions: 5, studyMinutes: 240),
      const Duration(minutes: 30),
    );
  });

  test('turns definition statements into what-is flashcards', () {
    final cards = FlashcardParser.parse('''
Inheritance in Java: Java has an object-oriented programming feature where one class can acquire properties and methods of another class.

Polymorphism is defined as the ability of an object to take many forms.

Encapsulation refers to bundling data and methods inside one class.
''');

    expect(cards, hasLength(3));
    expect(cards[0].front, 'What is Inheritance in Java?');
    expect(cards[0].back, contains('acquire properties'));
    expect(cards[1].front, 'What is Polymorphism?');
    expect(cards[1].back, contains('many forms'));
    expect(cards[2].front, 'What is Encapsulation?');
  });

  test('captures compound technical subjects with the definition FSM', () {
    final cards = FlashcardParser.parse('''
The TextField class is a text component that allows the editing of a single line text.
''');

    expect(cards, hasLength(1));
    expect(cards.single.front, 'What is the TextField class?');
    expect(cards.single.back, contains('allows the editing'));
  });

  test('generates grammatical cards from the Swing benchmark PDF text', () {
    final cards = FlashcardParser.parse('''
JLabel A JLabel is an object component for placing text in a container.
(3)JTextField:
The object of a JTextField class is a text component that allows the editing of a single line text.
(4)JTextArea
The object of a JTextArea class is a multi line region that displays text.
''');

    expect(cards.any((card) => card.front == 'What is JLabel?'), isTrue);
    expect(cards.any((card) => card.front == 'What is JTextField?'), isTrue);
    expect(cards.any((card) => card.front == 'What is JTextArea?'), isTrue);
    expect(cards.every((card) => !card.front.contains(' A JLabel')), isTrue);
    expect(
      cards
          .singleWhere((card) => card.front == 'What is JTextField?')
          .back,
      startsWith('A JTextField is a text component'),
    );
  });

  test('extracts cards from Swing-style headings and explanations', () {
    final cards = FlashcardParser.parse('''
Swing
Java Swing is a part of Java Foundation Classes that is used to create window-based applications.

Container
Containers are an integral part of Swing GUI components. A container provides a space where a component can be located.

JFrame
JFrame works like the main window where labels, buttons, and textfields are added to create a GUI.

JButton
The JButton class creates a labeled button that produces an action when pushed.
''', maxCards: 30);

    expect(cards.length, greaterThanOrEqualTo(4));
    expect(cards.any((card) => card.front == 'What is Swing?'), isTrue);
    expect(cards.any((card) => card.front == 'What is Container?'), isTrue);
    expect(cards.any((card) => card.front == 'What is JFrame?'), isTrue);
    expect(cards.any((card) => card.front == 'What is Java?'), isFalse);
  });

  test('honors the requested maximum card count', () {
    final notes = List.generate(
      80,
      (index) =>
          'Topic$index: Topic$index is a study concept with a useful definition.',
    ).join('\n');
    expect(FlashcardParser.parse(notes, maxCards: 30), hasLength(30));
    expect(FlashcardParser.parse(notes, maxCards: 70), hasLength(70));
  });

  test('synthesizes only answers backed by the imported source', () {
    final index = StudyKnowledgeIndex()..addNotes('''
FCFS (First Come First Served)

Process synchronization is a mechanism that coordinates concurrent processes.
''', 'os-notes.pdf');
    final synth = StudyAnswerSynth(index);

    final expansion = synth.build(
        StudyIntentParser.parse('Write the expansion of FCFS'), 'paper.pdf');
    final definition = synth.build(
        StudyIntentParser.parse('Define process synchronization'), 'paper.pdf');
    final unknown = synth.build(
        StudyIntentParser.parse('Define deadlock prevention'), 'paper.pdf');

    expect(expansion.front, 'What does FCFS stand for?');
    expect(expansion.back, contains('First Come First Served'));
    expect(definition.back, contains('coordinates concurrent processes'));
    expect(unknown.needsSource, isTrue);
    expect(unknown.back, isEmpty);
  });

  test('schedules cards with Anki-style review intervals', () {
    final now = DateTime(2026, 9, 15, 12);
    const card = Flashcard(front: 'What is Dart?', back: 'A language.');

    expect(card.isDue(now), isTrue);

    final firstGood = card.scheduled(ReviewRating.good, now: now);
    expect(firstGood.intervalDays, 1);
    expect(firstGood.repetitions, 1);
    expect(firstGood.dueAt, now.add(const Duration(days: 1)));

    final secondGood = firstGood.scheduled(ReviewRating.good, now: now);
    expect(secondGood.intervalDays, 3);

    final again = secondGood.scheduled(ReviewRating.again, now: now);
    expect(again.repetitions, 0);
    expect(again.lapses, 1);
    expect(again.dueAt, now.add(const Duration(minutes: 10)));

    final easy = card.scheduled(ReviewRating.easy, now: now);
    expect(easy.intervalDays, 4);
    expect(easy.ease, greaterThan(card.ease));
  });
}
