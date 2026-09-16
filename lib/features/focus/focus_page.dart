import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import 'app_state.dart';

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
        Row(
          children: [
            Expanded(
              child: Text('Good focus, ${state.moniker}',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              onPressed: () => _rename(context, state.moniker),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Change name',
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text('A quiet room for your next useful hour.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _TimerCard(state: state)),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => _showTimerSettings(context, state),
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Timer settings',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: _MetricTile(
              label: 'TODAY',
              value: '${state.todayFocusMinutes}m',
              color: AppColors.peach,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricTile(
              label: 'STREAK',
              value: '${state.streak}d',
              color: AppColors.pink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricTile(
              label: 'CYCLE',
              value: '${state.completedSessions}/5',
              color: AppColors.teal,
            ),
          ),
        ]),
      ],
    );
  }

  Future<void> _rename(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('What should we call you?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && context.mounted) {
      await context.read<AppState>().updateMoniker(name);
    }
  }

  Future<void> _showTimerSettings(BuildContext context, AppState state) async {
    var focus = state.focusMinutes.toDouble();
    var rest = state.breakMinutes.toDouble();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Timer settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DurationSlider(
                label: 'FOCUS TIME',
                value: focus,
                min: 1,
                max: 120,
                onChanged: (value) => setDialogState(() => focus = value),
              ),
              _DurationSlider(
                label: 'REST TIME',
                value: rest,
                min: 1,
                max: 60,
                onChanged: (value) => setDialogState(() => rest = value),
              ),
              Text(
                'Long rest after cycle 5: ${(rest.round() * 5)} minutes',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await state.updateTimerSettings(
                  focusMinutes: focus.round(),
                  breakMinutes: rest.round(),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationSlider extends StatelessWidget {
  const _DurationSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label  ${value.round()}m',
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ],
      );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.mauve.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.blur_on_rounded, color: AppColors.mauve, size: 21),
        ),
        const SizedBox(width: 10),
        const Text(
          'POMLY',
          style: TextStyle(
            color: AppColors.mauve,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            fontSize: 13,
          ),
        ),
      ]);
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final total = (state.isBreak
        ? state.breakMinutes * (state.isLongBreak ? 5 : 1)
        : state.focusMinutes) *
      60;
    final progress = 1 - (state.remaining.inSeconds / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            state.isLongBreak
                ? 'LONG RECOVERY WINDOW'
                : state.isBreak
                    ? 'MICRO BREAK'
                    : 'DEEP FOCUS',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              letterSpacing: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            state.isRunning ? 'RUNNING' : 'READY',
            style: TextStyle(
              color: state.isRunning ? AppColors.teal : AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          width: 170,
          height: 170,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 9,
              backgroundColor: AppColors.mantle,
              color: state.isBreak ? AppColors.teal : AppColors.mauve,
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                _formatDuration(state.remaining),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Color(0xfff5e0ff),
                ),
              ),
              Text(
                state.isBreak
                    ? state.isLongBreak
                        ? 'cycle complete'
                        : 'breathe'
                    : 'session ${state.completedSessions + 1}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.read<AppState>().toggleTimer(),
              icon: Icon(
                state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(state.isRunning ? 'Pause' : 'Start'),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: () => context.read<AppState>().skipTimer(),
            icon: const Icon(Icons.skip_next_rounded),
            tooltip: 'Skip phase',
          ),
        ]),
      ]),
    );
  }
}

String _formatDuration(Duration duration) =>
    '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 13),
        decoration: BoxDecoration(
          color: AppColors.mantle,
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
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}
