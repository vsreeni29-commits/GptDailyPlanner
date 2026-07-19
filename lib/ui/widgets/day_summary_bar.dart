import 'package:flutter/material.dart';

import '../../domain/timeline_engine.dart';
import '../formatters.dart';

class DaySummaryBar extends StatelessWidget {
  const DaySummaryBar({required this.schedule, super.key});

  final DaySchedule schedule;

  @override
  Widget build(BuildContext context) {
    final finish = schedule.projectedFinish;
    if (finish == null) {
      return const SizedBox.shrink();
    }
    final sigma = schedule.stats.standardDeviation;
    final spread = Duration(milliseconds: (sigma * 2 * 60000).round());
    final low = finish.subtract(spread);
    final high = finish.add(spread);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[scheme.primaryContainer, scheme.tertiaryContainer],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_graph_rounded, color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(
                'PERT day projection',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${schedule.tasks.length} tasks',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: <Widget>[
              _Metric(
                label: 'Expected work',
                value: formatMinutes(schedule.stats.expected),
              ),
              _Metric(label: 'Projected finish', value: formatTime(finish)),
              _Metric(
                label: '95% confidence',
                value: '${formatTime(low)} – ${formatTime(high)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    ],
  );
}
