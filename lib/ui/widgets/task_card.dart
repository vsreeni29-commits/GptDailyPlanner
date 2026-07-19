import 'package:flutter/material.dart';

import '../../domain/timeline_engine.dart';
import '../../models/planner_task.dart';
import '../formatters.dart';
import 'pert_chips.dart';

enum _TaskMenuAction { edit, postpone, delete }

class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.item,
    required this.index,
    required this.now,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onAddSubtask,
    required this.onDelete,
    required this.onPostpone,
    super.key,
  });

  final ScheduledTask item;
  final int index;
  final DateTime now;
  final VoidCallback onToggleComplete;
  final void Function(PlannerTask task, DateTime scheduledStart) onEdit;
  final void Function(PlannerTask parent, DateTime scheduledStart) onAddSubtask;
  final void Function(PlannerTask task) onDelete;
  final VoidCallback onPostpone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final countdown = _countdownLabel(item, now);
    final statusColor = item.isCompleted
        ? scheme.secondary
        : now.isAfter(item.end)
        ? scheme.error
        : now.isAfter(item.start)
        ? scheme.primary
        : scheme.outline;

    return Opacity(
      opacity: item.isCompleted ? 0.72 : 1,
      child: Card(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${formatTime(item.start)} – ${formatTime(item.end)}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              countdown,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.task.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        decoration: item.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                ),
                                if (item.task.notes
                                    .trim()
                                    .isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.task.notes,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _TaskMenu(
                            item: item,
                            onEdit: () => onEdit(item.task, item.start),
                            onDelete: () => onDelete(item.task),
                            onPostpone: onPostpone,
                          ),
                          if (!item.isCompleted)
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle_rounded),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      PertChips(stats: item.stats),
                      if (item.task.isStartPinned ||
                          item.wasShifted) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Icon(
                              item.wasShifted
                                  ? Icons.warning_amber_rounded
                                  : Icons.push_pin_outlined,
                              size: 16,
                              color: item.wasShifted
                                  ? scheme.error
                                  : scheme.outline,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                item.wasShifted
                                    ? 'Fixed start conflicted and was shifted to prevent overlap.'
                                    : 'Fixed start',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: item.wasShifted
                                          ? scheme.error
                                          : scheme.outline,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (item.subtasks.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: item.subtasks
                                .map(
                                  (subtask) => _SubtaskRow(
                                    item: subtask,
                                    onEdit: onEdit,
                                    onDelete: onDelete,
                                    onAddSubtask: onAddSubtask,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          FilledButton.tonalIcon(
                            onPressed: onToggleComplete,
                            icon: Icon(
                              item.isCompleted
                                  ? Icons.undo_rounded
                                  : Icons.check_circle_outline_rounded,
                            ),
                            label: Text(item.isCompleted ? 'Undo' : 'Complete'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () =>
                                onAddSubtask(item.task, item.start),
                            icon: const Icon(Icons.account_tree_outlined),
                            label: const Text('Subtask'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskMenu extends StatelessWidget {
  const _TaskMenu({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onPostpone,
  });

  final ScheduledTask item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPostpone;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_TaskMenuAction>(
    tooltip: 'Task actions',
    onSelected: (action) {
      switch (action) {
        case _TaskMenuAction.edit:
          onEdit();
          break;
        case _TaskMenuAction.postpone:
          onPostpone();
          break;
        case _TaskMenuAction.delete:
          onDelete();
          break;
      }
    },
    itemBuilder: (context) => <PopupMenuEntry<_TaskMenuAction>>[
      const PopupMenuItem(
        value: _TaskMenuAction.edit,
        child: ListTile(
          leading: Icon(Icons.edit_outlined),
          title: Text('Edit'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      if (!item.isCompleted)
        const PopupMenuItem(
          value: _TaskMenuAction.postpone,
          child: ListTile(
            leading: Icon(Icons.redo_rounded),
            title: Text('Postpone to tomorrow'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      const PopupMenuItem(
        value: _TaskMenuAction.delete,
        child: ListTile(
          leading: Icon(Icons.delete_outline_rounded),
          title: Text('Delete'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ],
  );
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onAddSubtask,
  });

  final ScheduledTask item;
  final void Function(PlannerTask task, DateTime scheduledStart) onEdit;
  final void Function(PlannerTask task) onDelete;
  final void Function(PlannerTask parent, DateTime scheduledStart) onAddSubtask;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: <Widget>[
        const Icon(Icons.subdirectory_arrow_right_rounded, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.task.title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${formatTime(item.start)} – ${formatTime(item.end)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              PertChips(stats: item.stats, compact: true),
              if (item.subtasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 5),
                  child: Column(
                    children: item.subtasks
                        .map(
                          (nested) => _SubtaskRow(
                            item: nested,
                            onEdit: onEdit,
                            onDelete: onDelete,
                            onAddSubtask: onAddSubtask,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Add nested subtask',
          onPressed: () => onAddSubtask(item.task, item.start),
          icon: const Icon(Icons.add_rounded, size: 20),
        ),
        IconButton(
          tooltip: 'Edit subtask',
          onPressed: () => onEdit(item.task, item.start),
          icon: const Icon(Icons.edit_outlined, size: 19),
        ),
        IconButton(
          tooltip: 'Delete subtask',
          onPressed: () => onDelete(item.task),
          icon: const Icon(Icons.delete_outline_rounded, size: 19),
        ),
      ],
    ),
  );
}

String _countdownLabel(ScheduledTask item, DateTime now) {
  if (item.isCompleted) {
    return 'Completed';
  }
  if (now.isBefore(item.start)) {
    return 'Starts in ${formatClockDuration(item.start.difference(now))}';
  }
  if (now.isBefore(item.end)) {
    return '${formatClockDuration(item.end.difference(now))} left';
  }
  return 'Overdue ${formatClockDuration(now.difference(item.end))}';
}
