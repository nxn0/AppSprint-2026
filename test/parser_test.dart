import 'package:flutter_test/flutter_test.dart';
import 'package:pomly/data/models.dart';
import 'package:pomly/services.dart';
import 'package:pomly/services/local_flashcard_engine.dart';

void main() {
  test('creates subject-first definition cards', () {
    final cards = LocalFlashcardEngine.generateCards('''
JLabel is a component for placing text in a container.
JButton is used to create a labeled button.
''');

    expect(cards.length, 2);
    expect(cards.first.front, 'What is JLabel?');
    expect(cards.first.back, contains('component for placing text'));
    expect(cards.every((card) => card.type == CardType.standard), isTrue);
  });

  test('cloze hides only the capitalized subject', () {
    final cards = LocalFlashcardEngine.generateCards(
      'A JPanel provides space in which any other component can be placed.',
    );

    expect(cards, hasLength(1));
    expect(cards.single.type, CardType.cloze);
    expect(cards.single.front, contains('[...]'));
    expect(cards.single.front, contains('provides space'));
    expect(cards.single.back, 'JPanel');
    expect(cards.single.front, endsWith('.'));
  });

  test('does not cloze stopwords or cut sentences', () {
    final cards = LocalFlashcardEngine.generateCards(
      'Using JPanel with care keeps layouts readable. '
      'The LayoutManager controls component positions.',
    );

    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.back.toLowerCase() != 'using'), isTrue);
    expect(cards.every((card) => card.front.endsWith('.')), isTrue);
  });

  test('removes duplicated PDF headings before cloze replacement', () {
    final cards = LocalFlashcardEngine.generateCards(
      'JFrame JFrame works like the main window where components are added.',
    );

    expect(cards, hasLength(1));
    expect(cards.single.back, 'JFrame');
    expect(cards.single.front,
        '[...] works like the main window where components are added.');
    expect(cards.single.front.contains('JFrame'), isFalse);
  });

  test('uses bullet content as the answer instead of creating a cloze', () {
    final cards = LocalFlashcardEngine.generateCards(
      'Inheritance in Java is used for the following: o Method Overriding '
      '(so runtime polymorphism can be achieved).',
    );

    expect(cards, hasLength(1));
    expect(cards.single.type, CardType.standard);
    expect(cards.single.front, 'What is Inheritance in Java used for?');
    expect(cards.single.back,
        'Method Overriding (so runtime polymorphism can be achieved)');
  });

  test('skips PDF headings, discourse words, and malformed tokens', () {
    final cards = LocalFlashcardEngine.generateCards('''
JFrame JFrame works like the main window where components are added.
Unlike AWT, Java Swing provides lightweight components.
Swing package provides classes such as API(Application Program Interface).
''');

    expect(cards.every((card) => card.back != 'Unlike'), isTrue);
    expect(cards.every((card) => card.back != 'APIApplication'), isTrue);
    expect(cards.every(LocalFlashcardEngine.isReviewable), isTrue);
    expect(cards.where((card) => card.back == 'JFrame'), hasLength(1));
  });

  test('rejects persisted garbage regardless of old card type', () {
    const oldCloze = Flashcard(
      id: 'old-1',
      front: '[...] JFrame works like the main window.',
      back: 'For',
      type: CardType.cloze,
    );
    const oldStandard = Flashcard(
      id: 'old-2',
      front: '[...] AWT provides components.',
      back: 'APIApplication',
    );

    expect(LocalFlashcardEngine.isReviewable(oldCloze), isFalse);
    expect(LocalFlashcardEngine.isReviewable(oldStandard), isFalse);
  });

  test('ignores code from imported PDFs', () {
    final cards = LocalFlashcardEngine.generateCards('''
import javax.swing.*;
public class SwingExample { JFrame f = new JFrame(); f.setVisible(true); }
JButton is used to create a labeled button.
''');

    expect(cards, hasLength(1));
    expect(cards.single.front, 'What is JButton?');
  });

  test('produces at least 25 cards from a sufficiently large source', () {
    final text = List.generate(
      30,
      (index) => 'Component$index is used to place item $index in a container.',
    ).join(' ');

    final cards = FlashcardParser.parse(text);

    expect(cards.length, greaterThanOrEqualTo(25));
  });

  test('keeps Anki scheduling intact', () {
    final now = DateTime(2026, 9, 15, 12);
    const card = Flashcard(
      id: 'card-1',
      front: 'What is Dart?',
      back: 'A language.',
    );

    expect(card.scheduled(ReviewRating.good, now: now).intervalDays, 1);
    expect(card.scheduled(ReviewRating.easy, now: now).intervalDays, 4);
  });

  test('parses raw text pairs without sentence punctuation', () {
    final cards = FlashcardParser.parse('''
Q: What is a closure? A: A function with lexical scope
term :: definition
front -> back
''');

    expect(cards, hasLength(3));
    expect(cards[0].front, 'What is a closure?');
    expect(cards[1].back, 'definition');
    expect(cards[2].back, 'back');
  });

  test('parses question and answer on separate lines', () {
    final cards = FlashcardParser.parse('''
Q: Mention the solution for starvation in priority process scheduling.
A: Aging: gradually increase the priority of waiting processes so that processes waiting for a long time eventually get CPU access.
''');

    expect(cards, hasLength(1));
    expect(cards.single.front,
        'Mention the solution for starvation in priority process scheduling.');
    expect(cards.single.back, startsWith('Aging: gradually increase'));
  });
}
