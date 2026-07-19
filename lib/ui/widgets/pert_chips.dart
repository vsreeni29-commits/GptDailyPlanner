import 'package:flutter/material.dart';

import '../../models/pert.dart';
import '../formatters.dart';

class PertChips extends StatelessWidget {
  const PertChips({required this.stats, this.compact = false, super.key});

  final PertStats stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelSmall;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        if (!compact)
          _Chip(
            label:
                'O ${formatNumber(stats.optimistic)} · M ${formatNumber(stats.mostLikely)} · P ${formatNumber(stats.pessimistic)}',
            color: colorScheme.surfaceContainerHighest,
            textStyle: textStyle,
          ),
        _Chip(
          label:
              'TE ${formatMinutes(stats.expected)} ± ${formatMinutes(stats.standardDeviation)}',
          color: colorScheme.primaryContainer,
          textStyle: textStyle?.copyWith(color: colorScheme.onPrimaryContainer),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.textStyle});

  final String label;
  final Color color;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: textStyle),
  );
}
