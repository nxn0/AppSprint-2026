import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'models.dart';
import 'services.dart';

const _mantle = Color(0xff181825);
const _surface = Color(0xff313244);
const _muted = Color(0xffa6adc8);
const _mauve = Color(0xffcba6f7);
const _pink = Color(0xfff5c2e7);
const _peach = Color(0xfffab387);
const _teal = Color(0xff94e2d5);

class FocusPage extends StatelessWidget {
  const FocusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        const _BrandHeader(),
        const SizedBox(height: 26),
        Text('Good focus, ${state.moniker}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        const Text('A quiet room for your next useful hour.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 24),
        _TimerCard(state: state),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
              child: _MetricTile(
                  label: 'TODAY',
                  value: '${state.totalFocusMinutes}m',
                  color: _peach)),
          const SizedBox(width: 12),
          Expanded(
              child: _MetricTile(
                  label: 'STREAK', value: '${state.streak}d', color: _pink)),
          const SizedBox(width: 12),
          Expanded(
              child: _MetricTile(
                  label: 'CYCLE',
                  value: '${state.completedSessions}/5',
                  color: _teal)),
        ]),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: _mauve.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.blur_on_rounded, color: _mauve, size: 21),
        ),
        const SizedBox(width: 10),
        const Text('POMLY',
            style: TextStyle(
                color: _mauve,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                fontSize: 13)),
      ]);
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
                  prefixIcon: Icon(Icons.menu_book_outlined)),
              items: [
                for (var index = 0; index < state.decks.length; index++)
                  DropdownMenuItem<String>(
                      value: state.decks[index].id,
                      child: Text('${index + 1}. ${state.decks[index].title}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (deckId) {
                if (deckId != null) onChanged(deckId);
              })),
      const SizedBox(width: 8),
      IconButton.filledTonal(
          onPressed: () => onDeleted(value!),
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'Delete notebook'),
    ]);
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final total = state.isBreak
        ? (state.isLongBreak
                ? AdaptivePlan.largeBreak(
                    completedSessions: state.completedSessions,
                    studyMinutes: state.totalFocusMinutes)
                : const Duration(minutes: 5))
            .inSeconds
        : 25 * 60;
    final progress = 1 - (state.remaining.inSeconds / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
              state.isLongBreak
                  ? 'LONG RECOVERY WINDOW'
                  : state.isBreak
                      ? 'MICRO BREAK'
                      : 'DEEP FOCUS',
              style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.bold)),
          Text(state.isRunning ? 'RUNNING' : 'READY',
              style: TextStyle(
                  color: state.isRunning ? _teal : _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          width: 170,
          height: 170,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
                value: progress,
                strokeWidth: 9,
                backgroundColor: _mantle,
                color: state.isBreak ? _teal : _mauve),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_formatDuration(state.remaining),
                  style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Color(0xfff5e0ff))),
              Text(
                  state.isBreak
                      ? state.isLongBreak
                          ? 'cycle complete'
                          : 'breathe'
                      : 'session ${state.completedSessions + 1}',
                  style: const TextStyle(color: _muted, fontSize: 11)),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
                  onPressed: () => context.read<AppState>().toggleTimer(),
                  icon: Icon(state.isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  label: Text(state.isRunning ? 'Pause' : 'Start'))),
          const SizedBox(width: 10),
          IconButton.filled(
              onPressed: () => context.read<AppState>().skipTimer(),
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip phase'),
        ]),
      ]),
    );
  }
}

String _formatDuration(Duration duration) =>
    '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 13),
        decoration: BoxDecoration(
            color: _mantle, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _muted, fontSize: 9, letterSpacing: 1)),
            const SizedBox(height: 7),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 21, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

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
          const Text('Study library',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text('Each import stays in its own notebook.',
              style: TextStyle(color: _muted)),
          const SizedBox(height: 22),
          if (state.decks.isNotEmpty)
            _DeckSelector(
                state: state,
                onDeleted: _confirmDeleteDeck,
                onChanged: (deckId) {
                  context.read<AppState>().selectDeck(deckId);
                  setState(() => _active = 0);
                }),
          if (state.decks.isNotEmpty) const SizedBox(height: 18),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _mantle, borderRadius: BorderRadius.circular(18)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LOCAL PARSER',
                        style: TextStyle(
                            color: _mauve,
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text(
                        'Import a selectable-text PDF. Extraction stays on this device.',
                        style: TextStyle(color: _muted, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('CARD TARGET',
                              style: TextStyle(
                                  color: _muted,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.bold)),
                          Text('$_cardLimit cards',
                              style:
                                  const TextStyle(color: _mauve, fontSize: 12)),
                        ]),
                    Slider(
                        value: _cardLimit.toDouble(),
                        min: 30,
                        max: 70,
                        divisions: 40,
                        label: '$_cardLimit',
                        onChanged: (value) =>
                            setState(() => _cardLimit = value.round())),
                    const SizedBox(height: 4),
                    TextField(
                        controller: _notes,
                        maxLines: 5,
                        decoration: const InputDecoration(
                            hintText:
                                'Q: What is a closure? A: A function with its lexical scope.\nterm :: definition\n- [ ] front -> back')),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: () async {
                              final parsed = FlashcardParser.parse(_notes.text,
                                  maxCards: _cardLimit, source: 'Pasted notes');
                              await context.read<AppState>().addDeck(
                                  title: 'Notes ${state.decks.length + 1}',
                                  parsed: parsed,
                                  sourceName: 'Pasted notes');
                              _notes.clear();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(
                                        '${parsed.length} cards added locally')));
                              }
                            },
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: const Text('Extract cards'))),
                    const SizedBox(height: 10),
                    SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                            onPressed: _isImporting ? null : _importPdf,
                            icon: _isImporting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.picture_as_pdf_outlined),
                            label: Text(_isImporting
                                ? 'Reading PDF locally...'
                                : 'Import PDF locally'))),
                  ])),
          const SizedBox(height: 24),
          if (deck == null || deck.cards.isEmpty)
            const _EmptyState()
          else ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('YOUR DECK',
                  style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.bold)),
              Text('${deck.cards.length} cards',
                  style: const TextStyle(color: _muted, fontSize: 11))
            ]),
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
                      label: const Text('Previous'))),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: activeIndex >= deck.cards.length - 1
                          ? null
                          : () => setState(() => _active = activeIndex + 1),
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Next'))),
            ]),
            const SizedBox(height: 10),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: () =>
                        context.read<AppState>().toggleDeckMastery(activeIndex),
                    icon: Icon(deck.cards[activeIndex].isMastered
                        ? Icons.check_circle
                        : Icons.circle_outlined),
                    label: Text(deck.cards[activeIndex].isMastered
                        ? 'Mastered'
                        : 'Mark mastered'))),
          ],
        ]);
  }

  Future<void> _importPdf() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
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
      final parsed = FlashcardParser.parse(text,
          maxCards: _cardLimit, source: result.files.single.name);
      final sourceName = result.files.single.name;
      final title =
          sourceName.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
      await appState.addDeck(
          title: title.isEmpty ? 'PDF ${appState.decks.length + 1}' : title,
          parsed: parsed,
          sourceName: sourceName);
      if (!mounted) return;
      _showMessage(parsed.isEmpty
          ? 'No selectable question and answer pairs found.'
          : '${parsed.length} cards imported locally.');
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
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppState>().deleteDeck(deckId);
      setState(() => _active = 0);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: _mantle, borderRadius: BorderRadius.circular(18)),
      child: const Column(children: [
        Icon(Icons.style_outlined, color: _muted, size: 30),
        SizedBox(height: 10),
        Text('Your deck is quiet.',
            style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('Paste a few notes above to make the first cards.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12))
      ]));
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
          color: _mauve.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _mauve.withValues(alpha: .4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CARD ${(index + 1).toString().padLeft(2, '0')}',
                style: const TextStyle(
                    color: _mauve,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(card.front,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Text(card.back,
                style: const TextStyle(color: _muted, fontSize: 13)),
            const Spacer(),
          ],
        ),
      );
}

class StreakPage extends StatefulWidget {
  const StreakPage({super.key});

  @override
  State<StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends State<StreakPage> {
  final _todoController = TextEditingController();

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final active = state.days
        .where((day) => day.minutes > 0)
        .fold<int>(0, (sum, day) => sum + day.minutes);
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          const Text('Streak signal',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text('Consistency with room for real life.',
              style: TextStyle(color: _muted)),
          const SizedBox(height: 22),
          Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  color: _mantle, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: _peach, size: 42),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${state.streak} days',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _peach)),
                  const Text('current focus rhythm',
                      style: TextStyle(color: _muted, fontSize: 12))
                ]),
              ])),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: _StatBlock(
                    label: 'FOCUS LOGGED', value: '${active}m', color: _teal)),
            const SizedBox(width: 12),
            const Expanded(
                child: _StatBlock(
                    label: 'REST ALLOWANCE', value: '3d', color: _pink))
          ]),
          const SizedBox(height: 24),
          _TodoSection(
              controller: _todoController,
              todos: state.todos,
              onAdd: () async {
                await context.read<AppState>().addTodo(_todoController.text);
                _todoController.clear();
              },
              onToggle: context.read<AppState>().toggleTodo,
              onDelete: context.read<AppState>().deleteTodo),
          const SizedBox(height: 24),
          _StreakBars(days: state.days),
          const SizedBox(height: 24),
          const Text('GRACE LOGIC',
              style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const _RuleRow(
              icon: Icons.check_rounded,
              color: _teal,
              text: 'Study days extend the active rhythm.'),
          const _RuleRow(
              icon: Icons.hotel_rounded,
              color: _pink,
              text: 'A named rest day preserves your rhythm.'),
          const _RuleRow(
              icon: Icons.refresh_rounded,
              color: _peach,
              text: 'Three unexplained quiet days reset it.'),
          const SizedBox(height: 22),
          OutlinedButton.icon(
              onPressed: () => _showRestDialog(context),
              icon: const Icon(Icons.hotel_rounded),
              label: const Text('Log a rest day')),
        ]);
  }

  Future<void> _showRestDialog(BuildContext context) async {
    final reasons = ['Recovery day', 'Travel', 'Exams', 'Health'];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why are you resting?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              ...reasons.map(
                (reason) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reason),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    context.read<AppState>().logRest(reason);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodoSection extends StatelessWidget {
  const _TodoSection({
    required this.controller,
    required this.todos,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
  });

  final TextEditingController controller;
  final List<TodoItem> todos;
  final VoidCallback onAdd;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY\'S TODO',
              style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onAdd(),
                    decoration: const InputDecoration(
                        hintText: 'Add a study task',
                        prefixIcon: Icon(Icons.add_task_rounded)))),
            const SizedBox(width: 8),
            IconButton.filled(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add todo'),
          ]),
          if (todos.isEmpty)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('No tasks yet. Add one small next step.',
                    style: TextStyle(color: _muted, fontSize: 12)))
          else
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                    children: todos
                        .map((todo) => _TodoRow(
                            todo: todo,
                            onToggle: onToggle,
                            onDelete: onDelete))
                        .toList())),
        ],
      );
}

class _TodoRow extends StatelessWidget {
  const _TodoRow(
      {required this.todo, required this.onToggle, required this.onDelete});

  final TodoItem todo;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Checkbox(
              value: todo.isDone,
              onChanged: (_) => onToggle(todo.id),
              activeColor: _teal),
          Expanded(
              child: Text(todo.title,
                  style: TextStyle(
                      color: todo.isDone ? _muted : null,
                      decoration:
                          todo.isDone ? TextDecoration.lineThrough : null))),
          IconButton(
              onPressed: () => onDelete(todo.id),
              icon: const Icon(Icons.content_cut_rounded, size: 18),
              tooltip: 'Cut todo'),
        ]),
      );
}

class _StreakBars extends StatelessWidget {
  const _StreakBars({required this.days});

  final List<StudyDay> days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final recent = List.generate(
        7, (index) => now.subtract(Duration(days: 6 - index)));
    final minutes = recent.map((date) {
      final day = days.where((item) => _sameDate(item.date, date)).firstOrNull;
      return day?.minutes ?? 0;
    }).toList();
    final peak = max(1, minutes.fold<int>(0, max));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('STREAK + GAINS',
          style: TextStyle(
              color: _muted,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _surface, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            _BarLegend(label: 'STREAK', color: _peach),
            const SizedBox(height: 10),
            for (var index = 0; index < recent.length; index++)
              _DayBar(
                  label: _dayLabel(recent[index]),
                  value: minutes[index] > 0 ? 1 : 0,
                  maxValue: 1,
                  valueLabel: minutes[index] > 0 ? 'ON' : '--',
                  color: _peach),
            const SizedBox(height: 14),
            _BarLegend(label: 'STUDY GAINS', color: _teal),
            const SizedBox(height: 10),
            for (var index = 0; index < recent.length; index++)
              _DayBar(
                  label: _dayLabel(recent[index]),
                  value: minutes[index],
                  maxValue: peak,
                  valueLabel: '${minutes[index]}m',
                  color: _teal),
          ])),
    ]);
  }
}

class _BarLegend extends StatelessWidget {
  const _BarLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1)),
      ]);
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.valueLabel,
    required this.color,
  });

  final String label;
  final int value;
  final int maxValue;
  final String valueLabel;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          SizedBox(
              width: 28,
              child: Text(label,
                  style: const TextStyle(color: _muted, fontSize: 10))),
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                      minHeight: 7,
                      value: value / maxValue,
                      backgroundColor: _mantle,
                      color: color))),
          SizedBox(
              width: 34,
              child: Text(valueLabel,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: color, fontSize: 10))),
        ]),
      );
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month && left.day == right.day;

String _dayLabel(DateTime date) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];

class _StatBlock extends StatelessWidget {
  const _StatBlock(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _muted, fontSize: 9, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 11),
        Expanded(
            child:
                Text(text, style: const TextStyle(color: _muted, fontSize: 13)))
      ]));
}
