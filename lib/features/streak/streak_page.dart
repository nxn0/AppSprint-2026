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
    final loggedDays = state.days
        .where((day) => day.minutes > 0)
        .fold<int>(0, (sum, day) => sum + day.minutes);
    final active = max(loggedDays, state.totalFocusMinutes);
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
          Expanded(
            child: _StatBlock(
              label: 'REST ALLOWANCE',
              value: '${state.restAllowance}d',
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
        _ActivitySummary(
          days: state.days,
          todos: state.todos,
          liveFocusMinutes: state.todayFocusMinutes,
          weeklyMinutesGoal: state.weeklyMinutesGoal,
          weeklyTodoGoal: state.weeklyTodoGoal,
          onMinutesGoalChanged: (value) =>
              context.read<AppState>().updateWeeklyMinutesGoal(value),
          onTodoGoalChanged: (value) =>
              context.read<AppState>().updateWeeklyTodoGoal(value),
        ),
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
            Column(children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: LinearProgressIndicator(
                  value:
                      todos.where((todo) => todo.isDone).length / todos.length,
                  minHeight: 6,
                  backgroundColor: AppColors.mantle,
                  color: AppColors.teal,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${todos.where((todo) => todo.isDone).length}/${todos.length} complete',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: todos
                      .map((todo) => _TodoRow(
                            todo: todo,
                            onToggle: onToggle,
                            onDelete: onDelete,
                          ))
                      .toList(),
                ),
              ),
            ]),
        ],
      );
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({
    required this.days,
    required this.todos,
    required this.liveFocusMinutes,
    required this.weeklyMinutesGoal,
    required this.weeklyTodoGoal,
    required this.onMinutesGoalChanged,
    required this.onTodoGoalChanged,
  });

  final List<StudyDay> days;
  final List<TodoItem> todos;
  final int liveFocusMinutes;
  final int weeklyMinutesGoal;
  final int weeklyTodoGoal;
  final ValueChanged<int> onMinutesGoalChanged;
  final ValueChanged<int> onTodoGoalChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final periods = <(String, DateTime)>[
      ('WEEK', DateTime(now.year, now.month, now.day - now.weekday + 1)),
      ('MONTH', DateTime(now.year, now.month, 1)),
      ('YEAR', DateTime(now.year, 1, 1)),
    ];
    final minutes = <int>[
      for (final period in periods) _minutesSince(period.$2),
    ];
    final todoTotals = <(int, int)>[
      for (final period in periods) _todosSince(period.$2),
    ];
    final minutePeak = max(1, minutes.fold<int>(0, max));
    final todoPeak =
        max(1, todoTotals.fold<int>(0, (peak, value) => max(peak, value.$1)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ACTIVITY WINDOWS',
          style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      _ActivityBarGroup(
        title: 'MINUTES STUDIED',
        periods: periods,
        values: minutes,
        peak: minutePeak,
        color: AppColors.teal,
        valueLabel: (index) => '${minutes[index]}/${[
          weeklyMinutesGoal,
          weeklyMinutesGoal * 4,
          weeklyMinutesGoal * 12,
        ][index]}m',
        goals: [
          weeklyMinutesGoal,
          weeklyMinutesGoal * 4,
          weeklyMinutesGoal * 12,
        ],
        onSetGoal: () => _showGoalDialog(
          context,
          title: 'Weekly minutes goal',
          current: weeklyMinutesGoal,
          suffix: 'minutes',
          onSave: onMinutesGoalChanged,
        ),
      ),
      const SizedBox(height: 10),
      _ActivityBarGroup(
        title: 'TODO PROGRESS',
        periods: periods,
        values: <int>[for (final value in todoTotals) value.$1],
        peak: todoPeak,
        valueLabel: (index) =>
          '${todoTotals[index].$2}/${[weeklyTodoGoal, weeklyTodoGoal * 4, weeklyTodoGoal * 12][index]}',
        goals: [weeklyTodoGoal, weeklyTodoGoal * 4, weeklyTodoGoal * 12],
        onSetGoal: () => _showGoalDialog(
          context,
          title: 'Weekly todo goal',
          current: weeklyTodoGoal,
          suffix: 'completed todos',
          onSave: onTodoGoalChanged,
        ),
        segments: <({int pending, int done})>[
          for (final value in todoTotals)
            (
              pending: max(0, value.$1 - value.$2),
              done: value.$2,
            ),
        ],
      ),
    ]);
  }

  int _minutesSince(DateTime start) {
    final logged = days
        .where((day) => !day.date.isBefore(start))
        .fold(0, (sum, day) => sum + day.minutes);
    final today = DateTime.now();
    return today.isBefore(start) ? logged : max(logged, liveFocusMinutes);
  }

  (int, int) _todosSince(DateTime start) {
    final today = DateTime.now();
    final logged = days
        .where((day) =>
            !day.date.isBefore(start) &&
            !(day.date.year == today.year &&
                day.date.month == today.month &&
                day.date.day == today.day))
        .fold((
      0,
      0
    ), (sum, day) => (sum.$1 + day.createdTodos, sum.$2 + day.completedTodos));
    if (today.isBefore(start)) return logged;
    final done = todos.where((todo) => todo.isDone).length;
    return (logged.$1 + todos.length, logged.$2 + done);
  }

  Future<void> _showGoalDialog(
    BuildContext context, {
    required String title,
    required int current,
    required String suffix,
    required ValueChanged<int> onSave,
  }) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _GoalDialog(
        title: title,
        current: current,
        suffix: suffix,
      ),
    );
    if (value != null && value > 0 && context.mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (context.mounted) onSave(value);
    }
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({
    required this.title,
    required this.current,
    required this.suffix,
  });

  final String title;
  final int current;
  final String suffix;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.current}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: widget.suffix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              int.tryParse(_controller.text.trim()),
            ),
            child: const Text('Save'),
          ),
        ],
      );
}

class _ActivityBarGroup extends StatelessWidget {
  const _ActivityBarGroup({
    required this.title,
    required this.periods,
    required this.values,
    required this.peak,
    required this.valueLabel,
    this.color,
    this.segments,
    required this.goals,
    required this.onSetGoal,
  });

  final String title;
  final List<(String, DateTime)> periods;
  final List<int> values;
  final int peak;
  final String Function(int index) valueLabel;
  final Color? color;
  final List<({int pending, int done})>? segments;
  final List<int> goals;
  final VoidCallback onSetGoal;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title,
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: onSetGoal,
                  icon: const Icon(Icons.flag_outlined, size: 14),
                  label: const Text('Set weekly goal'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (segments != null)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActivityLegend(color: AppColors.pink, label: 'pending'),
                        SizedBox(width: 8),
                        _ActivityLegend(color: AppColors.teal, label: 'done'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          for (var index = 0; index < periods.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(
                  width: 52,
                  child: Text(periods[index].$1,
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          letterSpacing: 1)),
                ),
                Expanded(
                  child: segments == null
                      ? LinearProgressIndicator(
                          minHeight: 7,
                          value: values[index] / max(peak, goals[index]),
                          backgroundColor: AppColors.mantle,
                          color: color,
                        )
                      : _TodoBar(
                          pending: segments![index].pending,
                          done: segments![index].done,
                          totalPeak: max(peak, goals[index]),
                        ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(valueLabel(index),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: color ?? AppColors.muted, fontSize: 10)),
                ),
              ]),
            ),
        ]),
      );
}

class _TodoBar extends StatelessWidget {
  const _TodoBar(
      {required this.pending, required this.done, required this.totalPeak});

  final int pending;
  final int done;
  final int totalPeak;

  @override
  Widget build(BuildContext context) {
    final total = pending + done;
    if (total == 0) {
      return Container(height: 7, color: AppColors.mantle);
    }
    return SizedBox(
      height: 7,
      child: Row(children: [
        if (pending > 0)
          Expanded(
            flex: pending,
            child: Container(color: AppColors.pink),
          ),
        if (done > 0)
          Expanded(
            flex: done,
            child: Container(color: AppColors.teal),
          ),
        if (total < totalPeak)
          Expanded(
              flex: totalPeak - total,
              child: Container(color: AppColors.mantle)),
      ]),
    );
  }
}

class _ActivityLegend extends StatelessWidget {
  const _ActivityLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 8)),
      ]);
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
