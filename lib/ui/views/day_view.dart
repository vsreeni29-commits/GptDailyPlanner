import 'dart:async';

import 'package:flutter/material.dart';

import '../../controller/planner_controller.dart';
import '../../controller/planner_scope.dart';
import '../../domain/date_keys.dart';
import '../../models/planner_task.dart';
import '../dialogs/task_editor.dart';
import '../formatters.dart';
import '../widgets/day_summary_bar.dart';
import '../widgets/task_card.dart';

class DayView extends StatefulWidget {
  const DayView({super.key});

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    final schedule = controller.scheduleFor(controller.selectedDate);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: <Widget>[
            _DayNavigator(controller: controller),
            if (!schedule.isEmpty) DaySummaryBar(schedule: schedule),
            Expanded(
              child: schedule.isEmpty
                  ? _EmptyDay(
                      date: controller.selectedDate,
                      onAdd: () => _addTask(controller),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: schedule.tasks.length,
                      onReorder: (oldIndex, newIndex) =>
                          _reorder(controller, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final item = schedule.tasks[index];
                        return Padding(
                          key: ValueKey<String>(item.occurrenceId),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TaskCard(
                            item: item,
                            index: index,
                            now: _now,
                            onToggleComplete: () => _run(
                              controller.toggleComplete(
                                item.task,
                                controller.selectedDate,
                              ),
                            ),
                            onEdit: (task, start) => TaskEditor.show(
                              context,
                              selectedDate: controller.selectedDate,
                              suggestedStart: start,
                              task: task,
                            ),
                            onAddSubtask: (parent, start) => TaskEditor.show(
                              context,
                              selectedDate: controller.selectedDate,
                              suggestedStart: start,
                              parentId: parent.id,
                            ),
                            onDelete: _confirmDelete,
                            onPostpone: () => _run(
                              controller.postponeToTomorrow(
                                item.task,
                                controller.selectedDate,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _addTask(PlannerController controller) => TaskEditor.show(
    context,
    selectedDate: controller.selectedDate,
    suggestedStart: controller.suggestedStart(controller.selectedDate),
  );

  Future<void> _reorder(
    PlannerController controller,
    int oldIndex,
    int newIndex,
  ) async {
    final result = await controller.reorderDay(
      controller.selectedDate,
      oldIndex,
      newIndex,
    );
    if (mounted && result.message != null) {
      _showMessage(result.message!);
    }
  }

  Future<void> _confirmDelete(PlannerTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          'Delete “${task.title}”${PlannerScope.of(context).childrenOf(task.id).isEmpty ? '' : ' and all of its subtasks'}?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _run(PlannerScope.of(context).deleteTask(task.id));
    }
  }

  Future<void> _run(Future<ActionResult> operation) async {
    final result = await operation;
    if (mounted && result.message case final message?) {
      _showMessage(message);
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({required this.controller});

  final PlannerController controller;

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDate(controller.selectedDate, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Previous day',
            onPressed: () => controller.changeDay(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: controller.selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  controller.selectDate(picked);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: <Widget>[
                    Text(
                      isToday
                          ? 'Today'
                          : formatDayHeader(controller.selectedDate),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isToday)
                      Text(
                        formatDayHeader(controller.selectedDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: () => controller.changeDay(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          if (!isToday)
            TextButton(
              onPressed: () => controller.selectDate(DateTime.now()),
              child: const Text('Today'),
            ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.date, required this.onAdd});

  final DateTime date;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.route_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'Build your task chain',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'No tasks on ${formatDayHeader(date)}. Add the first task and PERT will calculate every end time.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add first task'),
          ),
        ],
      ),
    ),
  );
}
