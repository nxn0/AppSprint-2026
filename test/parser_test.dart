import 'package:flutter_test/flutter_test.dart';
import 'package:pomly/services.dart';

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
}
