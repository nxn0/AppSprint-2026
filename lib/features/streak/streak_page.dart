import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/models.dart';
import '../focus/app_state.dart';

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
        const Text(
          'Streak signal',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        const Text(
          'Consistency with room for real life.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.mantle,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            const Icon(Icons.local_fire_department_rounded,
                color: AppColors.peach, size: 42),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${state.streak} days',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.peach,
                ),
              ),
              const Text(
                'current focus rhythm',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              )
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: _StatBlock(
              label: 'FOCUS LOGGED',
              value: '${active}m',
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: _StatBlock(
              label: 'REST ALLOWANCE',
              value: '3d',
              color: AppColors.pink,
            ),
          ),
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
          onDelete: context.read<AppState>().deleteTodo,
        ),
        const SizedBox(height: 24),
        _StreakBars(days: state.days),
        const SizedBox(height: 24),
        const Text(
          'GRACE LOGIC',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const _RuleRow(
          icon: Icons.check_rounded,
          color: AppColors.teal,
          text: 'Study days extend the active rhythm.',
        ),
        const _RuleRow(
          icon: Icons.hotel_rounded,
          color: AppColors.pink,
          text: 'A named rest day preserves your rhythm.',
        ),
        const _RuleRow(
          icon: Icons.refresh_rounded,
          color: AppColors.peach,
          text: 'Three unexplained quiet days reset it.',
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: () => _showRestDialog(context),
          icon: const Icon(Icons.hotel_rounded),
          label: const Text('Log a rest day'),
        ),
      ],
    );
  }

  Future<void> _showRestDialog(BuildContext context) async {
    final reasons = ['Recovery day', 'Travel', 'Exams', 'Health'];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Why are you resting?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
          const Text(
            'TODAY\'S TODO',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                decoration: const InputDecoration(
                  hintText: 'Add a study task',
                  prefixIcon: Icon(Icons.add_task_rounded),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add todo',
            ),
          ]),
          if (todos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'No tasks yet. Add one small next step.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: todos
                    .map(
                      (todo) => _TodoRow(
                        todo: todo,
                        onToggle: onToggle,
                        onDelete: onDelete,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      );
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

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
            activeColor: AppColors.teal,
          ),
          Expanded(
            child: Text(
              todo.title,
              style: TextStyle(
                color: todo.isDone ? AppColors.muted : null,
                decoration: todo.isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          IconButton(
            onPressed: () => onDelete(todo.id),
            icon: const Icon(Icons.content_cut_rounded, size: 18),
            tooltip: 'Cut todo',
          ),
        ]),
      );
}

class _StreakBars extends StatelessWidget {
  const _StreakBars({required this.days});

  final List<StudyDay> days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final recent = List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));
    final minutes = recent.map((date) {
      final day = days.where((item) => _sameDate(item.date, date)).firstOrNull;
      return day?.minutes ?? 0;
    }).toList();
    final peak = max(1, minutes.fold<int>(0, max));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        'STREAK + GAINS',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          _BarLegend(label: 'STREAK', color: AppColors.peach),
          const SizedBox(height: 10),
          for (var index = 0; index < recent.length; index++)
            _DayBar(
              label: _dayLabel(recent[index]),
              value: minutes[index] > 0 ? 1 : 0,
              maxValue: 1,
              valueLabel: minutes[index] > 0 ? 'ON' : '--',
              color: AppColors.peach,
            ),
          const SizedBox(height: 14),
          _BarLegend(label: 'STUDY GAINS', color: AppColors.teal),
          const SizedBox(height: 10),
          for (var index = 0; index < recent.length; index++)
            _DayBar(
              label: _dayLabel(recent[index]),
              value: minutes[index],
              maxValue: peak,
              valueLabel: '${minutes[index]}m',
              color: AppColors.teal,
            ),
        ]),
      ),
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
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
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
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: value / maxValue,
                backgroundColor: AppColors.mantle,
                color: color,
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ),
        ]),
      );
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month && left.day == right.day;

String _dayLabel(DateTime date) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.icon,
    required this.color,
    required this.text,
  });

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
            child: Text(
              text,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          )
        ]),
      );
}
