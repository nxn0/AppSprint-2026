import 'dart:math';

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
  final _notes = TextEditingController();
  int _active = 0;
  bool _isImporting = false;
  int _cardLimit = 30;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final deck = state.selectedDeck;
    final activeIndex = deck == null || deck.cards.isEmpty
        ? 0
        : min(_active, deck.cards.length - 1);

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
              setState(() => _active = 0);
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
                    style: const TextStyle(color: AppColors.mauve, fontSize: 12),
                  ),
                ],
              ),
              Slider(
                value: _cardLimit.toDouble(),
                min: 30,
                max: 70,
                divisions: 40,
                label: '$_cardLimit',
                onChanged: (value) => setState(() => _cardLimit = value.round()),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _notes,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText:
                      'Q: What is a closure? A: A function with its lexical scope.\nterm :: definition\n- [ ] front -> back',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final parsed = FlashcardParser.parse(
                      _notes.text,
                      maxCards: _cardLimit,
                      source: 'Pasted notes',
                    );
                    await context.read<AppState>().addDeck(
                      title: 'Notes ${state.decks.length + 1}',
                      parsed: parsed,
                      sourceName: 'Pasted notes',
                    );
                    _notes.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${parsed.length} cards added locally')),
                      );
                    }
                  },
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Extract cards'),
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
                    _isImporting ? 'Reading PDF locally...' : 'Import PDF locally',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (deck == null || deck.cards.isEmpty)
          const _EmptyState()
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR DECK',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${deck.cards.length} cards',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Flashcard(card: deck.cards[activeIndex], index: activeIndex),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: activeIndex == 0
                    ? null
                    : () => setState(() => _active = activeIndex - 1),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: activeIndex >= deck.cards.length - 1
                    ? null
                    : () => setState(() => _active = activeIndex + 1),
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.read<AppState>().toggleDeckMastery(activeIndex),
              icon: Icon(
                deck.cards[activeIndex].isMastered
                    ? Icons.check_circle
                    : Icons.circle_outlined,
              ),
              label: Text(
                deck.cards[activeIndex].isMastered ? 'Mastered' : 'Mark mastered',
              ),
            ),
          ),
        ],
      ],
    );
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      setState(() => _active = 0);
    }
  }
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
          Text('Your deck is quiet.', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(
            'Paste a few notes above to make the first cards.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          )
        ]),
      );
}

class _Flashcard extends StatelessWidget {
  const _Flashcard({required this.card, required this.index});
  final Flashcard card;
  final int index;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(minHeight: 170),
        decoration: BoxDecoration(
          color: AppColors.mauve.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.mauve.withValues(alpha: .4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CARD ${(index + 1).toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: AppColors.mauve,
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              card.front,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Text(
              card.back,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const Spacer(),
          ],
        ),
      );
}
