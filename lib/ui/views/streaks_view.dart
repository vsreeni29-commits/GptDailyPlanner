import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controller/planner_controller.dart';
import '../../controller/planner_scope.dart';
import '../../domain/streak_calculator.dart';
import '../../models/planner_task.dart';
import '../formatters.dart';

class StreaksView extends StatelessWidget {
  const StreaksView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    final tasks = controller.repeatingTasks;
    if (tasks.isEmpty) {
      return const _EmptyStreaks();
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: tasks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _StreakCard(task: task, stats: controller.streakFor(task));
          },
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.task, required this.stats});

  final PlannerTask task;
  final StreakStats stats;

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    final today = DateTime.now();
    final scheduledToday = task.occursOn(today);
    final completeToday = task.isCompletedOn(today);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_fire_department_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        repeatLabel(task),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: scheduledToday
                      ? () async {
                          final result = await controller.toggleComplete(
                            task,
                            today,
                          );
                          if (context.mounted && result.message != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message!)),
                            );
                          }
                        }
                      : null,
                  icon: Icon(
                    completeToday
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                  ),
                  label: Text(
                    scheduledToday
                        ? completeToday
                              ? 'Done'
                              : 'Done today'
                        : 'Not today',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StreakMetric(
                    icon: '🔥',
                    label: 'Current',
                    value: '${stats.current}',
                  ),
                ),
                Expanded(
                  child: _StreakMetric(
                    icon: '🏆',
                    label: 'Best',
                    value: '${stats.best}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: stats.lastSevenDays
                  .map((day) => Expanded(child: _StreakDayDot(day: day)))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakMetric extends StatelessWidget {
  const _StreakMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      Text(icon, style: const TextStyle(fontSize: 24)),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ],
  );
}

class _StreakDayDot extends StatelessWidget {
  const _StreakDayDot({required this.day});

  final StreakDay day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = day.isComplete
        ? Colors.green
        : day.isScheduled
        ? scheme.outlineVariant
        : scheme.surfaceContainerHighest;
    return Column(
      children: <Widget>[
        Text(DateFormat.E().format(day.date).substring(0, 1)),
        const SizedBox(height: 5),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: day.isComplete
              ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
              : day.isScheduled
              ? Icon(Icons.remove_rounded, size: 17, color: scheme.outline)
              : null,
        ),
      ],
    );
  }
}

class _EmptyStreaks extends StatelessWidget {
  const _EmptyStreaks();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.local_fire_department_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'No repeating practices yet',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set a task to daily, weekly, or monthly to track its current streak, best streak, and last seven days.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
