import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/models.dart';
import '../focus/app_state.dart';
import '../../features/parser/parser.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  final _rawTextController = TextEditingController();
  bool _isImporting = false;
  int _cardLimit = 30;

  @override
  void dispose() {
    _rawTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final deck = state.selectedDeck;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        const Text(
          'Study library',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        const Text(
          'Each import stays in its own notebook.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        if (state.decks.isNotEmpty)
          _DeckSelector(
            state: state,
            onDeleted: _confirmDeleteDeck,
            onChanged: (deckId) {
              context.read<AppState>().selectDeck(deckId);
            },
          ),
        if (state.decks.isNotEmpty) const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.mantle,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LOCAL PARSER',
                style: TextStyle(
                  color: AppColors.mauve,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Import a selectable-text PDF. Extraction stays on this device.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CARD TARGET',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$_cardLimit cards',
                    style:
                        const TextStyle(color: AppColors.mauve, fontSize: 12),
                  ),
                ],
              ),
              Slider(
                value: _cardLimit.toDouble(),
                min: 30,
                max: 70,
                divisions: 40,
                label: '$_cardLimit',
                onChanged: (value) =>
                    setState(() => _cardLimit = value.round()),
              ),
              TextField(
                controller: _rawTextController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'RAW TEXT',
                  hintText: 'Paste notes, definitions, or study text',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _parseRawText,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Parse text into cards'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isImporting ? null : _importPdf,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    _isImporting
                        ? 'Reading PDF locally...'
                        : 'Import PDF locally',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (deck != null) _ReviewPanel(deck: deck),
        if (deck != null) const SizedBox(height: 24),
        if (deck == null || deck.cards.isEmpty) const _EmptyState(),
      ],
    );
  }

  Future<void> _parseRawText() async {
    final text = _rawTextController.text.trim();
    if (text.isEmpty) {
      _showMessage('Paste some text first.');
      return;
    }
    final state = context.read<AppState>();
    final parsed = FlashcardParser.parse(
      text,
      maxCards: _cardLimit,
      source: 'Pasted text',
    );
    await state.addDeck(
      title: 'Notes ${state.decks.length + 1}',
      parsed: parsed,
      sourceName: 'Pasted text',
    );
    _rawTextController.clear();
    if (mounted) {
      _showMessage(parsed.isEmpty
          ? 'No flashcards could be generated from that text.'
          : '${parsed.length} cards added locally.');
    }
  }

  Future<void> _importPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      _showMessage('Could not read that PDF file.');
      return;
    }
    setState(() => _isImporting = true);
    final appState = context.read<AppState>();
    try {
      final text = await PdfTextExtractorService.extract(bytes);
      final parsed = FlashcardParser.parse(
        text,
        maxCards: _cardLimit,
        source: result.files.single.name,
      );
      final sourceName = result.files.single.name;
      final title = sourceName.replaceFirst(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      await appState.addDeck(
        title: title.isEmpty ? 'PDF ${appState.decks.length + 1}' : title,
        parsed: parsed,
        sourceName: sourceName,
      );
      if (!mounted) return;
      _showMessage(
        parsed.isEmpty
            ? 'No selectable question and answer pairs found.'
            : '${parsed.length} cards imported locally.',
      );
    } catch (_) {
      if (mounted) _showMessage('That PDF could not be read locally.');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDeleteDeck(String deckId) async {
    final deck = context
        .read<AppState>()
        .decks
        .where((item) => item.id == deckId)
        .firstOrNull;
    if (deck == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${deck.title}?'),
        content: const Text('This removes the local notebook and its cards.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppState>().deleteDeck(deckId);
    }
  }
}

class _ReviewPanel extends StatefulWidget {
  const _ReviewPanel({required this.deck});

  final FlashcardDeck deck;

  @override
  State<_ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<_ReviewPanel> {
  bool _showAnswer = false;
  int _position = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final deck = state.selectedDeck ?? widget.deck;
    final dueIndexes = state.dueCardIndexes;
    if (dueIndexes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(children: [
          Icon(Icons.check_circle_outline_rounded, color: AppColors.teal),
          SizedBox(width: 12),
          Expanded(
            child:
                Text('You are caught up. Come back when the next card is due.'),
          ),
        ]),
      );
    }

    final selectedPosition = _position.clamp(0, dueIndexes.length - 1);
    final index = dueIndexes[selectedPosition];
    final card = deck.cards[index];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.teal.withValues(alpha: .35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text(
            'REVIEW SESSION',
            style: TextStyle(
              color: AppColors.teal,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text('${dueIndexes.length} due',
              style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ]),
        const SizedBox(height: 18),
        const Text('PROMPT',
            style: TextStyle(color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: GestureDetector(
              onTap: _showAnswer ? null : () => setState(() => _showAnswer = true),
              child: Text(card.front,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold)),
            ),
          ),
          IconButton(
            onPressed: () => _editCard(context, deck, card),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit flashcard',
          ),
        ]),
        if (_showAnswer) ...[
          const SizedBox(height: 14),
          const Text('ANSWER',
              style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 6),
          Text(card.back, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 18),
          const Text('How well did you remember it?',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: selectedPosition == 0
                    ? null
                    : () => setState(() {
                          _position--;
                          _showAnswer = false;
                        }),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: selectedPosition >= dueIndexes.length - 1
                    ? null
                    : () => setState(() {
                          _position++;
                          _showAnswer = false;
                        }),
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => state.toggleDeckMastery(index),
              icon: Icon(
                  card.isMastered ? Icons.check_circle : Icons.circle_outlined),
              label: Text(card.isMastered ? 'Mastered' : 'Mark mastered'),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _RatingButton(
                label: 'Again',
                color: AppColors.pink,
                onPressed: () => _rate(state, index, ReviewRating.again)),
            const SizedBox(width: 6),
            _RatingButton(
                label: 'Hard',
                color: AppColors.peach,
                onPressed: () => _rate(state, index, ReviewRating.hard)),
            const SizedBox(width: 6),
            _RatingButton(
                label: 'Good',
                color: AppColors.teal,
                onPressed: () => _rate(state, index, ReviewRating.good)),
            const SizedBox(width: 6),
            _RatingButton(
                label: 'Easy',
                color: AppColors.mauve,
                onPressed: () => _rate(state, index, ReviewRating.easy)),
          ]),
        ] else ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => setState(() => _showAnswer = true),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Show answer'),
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _rate(AppState state, int index, ReviewRating rating) async {
    await state.reviewDeckCard(index, rating);
    if (mounted) {
      setState(() {
        _showAnswer = false;
        _position = 0;
      });
    }
  }

  Future<void> _editCard(
      BuildContext context, FlashcardDeck deck, Flashcard card) async {
    final frontController = TextEditingController(text: card.front);
    final backController = TextEditingController(text: card.back);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit flashcard'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: frontController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Prompt'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: backController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Answer'),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
                dialogContext, (frontController.text, backController.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    frontController.dispose();
    backController.dispose();
    if (result != null && context.mounted) {
      await context.read<AppState>().updateDeckCard(
            deckId: deck.id,
            cardId: card.id,
            front: result.$1,
            back: result.$2,
          );
    }
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Expanded(
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(foregroundColor: color),
          child: Text(label),
        ),
      );
}

class _DeckSelector extends StatelessWidget {
  const _DeckSelector({
    required this.state,
    required this.onChanged,
    required this.onDeleted,
  });

  final AppState state;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onDeleted;

  @override
  Widget build(BuildContext context) {
    final selectedId = state.selectedDeckId;
    final value = state.decks.any((deck) => deck.id == selectedId)
        ? selectedId
        : state.decks.first.id;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'NOTEBOOK',
            prefixIcon: Icon(Icons.menu_book_outlined),
          ),
          items: [
            for (var index = 0; index < state.decks.length; index++)
              DropdownMenuItem<String>(
                value: state.decks[index].id,
                child: Text(
                  '${index + 1}. ${state.decks[index].title}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (deckId) {
            if (deckId != null) onChanged(deckId);
          },
        ),
      ),
      const SizedBox(width: 8),
      IconButton.filledTonal(
        onPressed: () => onDeleted(value!),
        icon: const Icon(Icons.delete_outline_rounded),
        tooltip: 'Delete notebook',
      ),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.mantle,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(children: [
          Icon(Icons.style_outlined, color: AppColors.muted, size: 30),
          SizedBox(height: 10),
          Text('Your deck is quiet.',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(
            'Paste a few notes above to make the first cards.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          )
        ]),
      );
}
