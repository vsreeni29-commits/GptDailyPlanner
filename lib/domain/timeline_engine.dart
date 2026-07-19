import '../models/pert.dart';
import '../models/planner_task.dart';
import 'date_keys.dart';

class ScheduledTask {
  const ScheduledTask({
    required this.task,
    required this.occurrenceDate,
    required this.start,
    required this.end,
    required this.stats,
    required this.isCompleted,
    required this.wasShifted,
    required this.subtasks,
  });

  final PlannerTask task;
  final DateTime occurrenceDate;
  final DateTime start;
  final DateTime end;
  final PertStats stats;
  final bool isCompleted;
  final bool wasShifted;
  final List<ScheduledTask> subtasks;

  String get occurrenceId => '${task.id}@${dateKey(occurrenceDate)}';

  Iterable<ScheduledTask> get flattened sync* {
    yield this;
    for (final subtask in subtasks) {
      yield* subtask.flattened;
    }
  }
}

class DaySchedule {
  const DaySchedule({
    required this.date,
    required this.tasks,
    required this.stats,
    required this.projectedFinish,
  });

  final DateTime date;
  final List<ScheduledTask> tasks;
  final PertStats stats;
  final DateTime? projectedFinish;

  bool get isEmpty => tasks.isEmpty;
}

class TimelineEngine {
  DaySchedule build(List<PlannerTask> allTasks, DateTime requestedDate) {
    final date = dateOnly(requestedDate);
    final children = <String, List<PlannerTask>>{};
    for (final task in allTasks.where((value) => value.parentId != null)) {
      children.putIfAbsent(task.parentId!, () => <PlannerTask>[]).add(task);
    }
    for (final values in children.values) {
      values.sort(_byOrder);
    }

    final roots =
        allTasks
            .where((task) => task.parentId == null && task.occursOn(date))
            .toList()
          ..sort(_byOrder);
    final cache = <String, PertStats>{};
    PertStats statsFor(PlannerTask task, [Set<String>? ancestors]) {
      final cached = cache[task.id];
      if (cached != null) {
        return cached;
      }
      final visited = <String>{...?ancestors};
      if (!visited.add(task.id)) {
        return PertStats.fromEstimate(task.estimate);
      }
      final nested = children[task.id] ?? const <PlannerTask>[];
      final stats = nested.isEmpty
          ? PertStats.fromEstimate(task.estimate)
          : PertStats.chain(nested.map((child) => statsFor(child, visited)));
      cache[task.id] = stats;
      return stats;
    }

    List<ScheduledTask> scheduleChildren(
      PlannerTask parent,
      DateTime start,
      bool parentCompleted,
    ) {
      var cursor = start;
      final result = <ScheduledTask>[];
      for (final child in children[parent.id] ?? const <PlannerTask>[]) {
        final stats = statsFor(child);
        final end = cursor.add(stats.expectedDuration);
        final nested = scheduleChildren(child, cursor, parentCompleted);
        result.add(
          ScheduledTask(
            task: child,
            occurrenceDate: date,
            start: cursor,
            end: end,
            stats: stats,
            isCompleted: parentCompleted,
            wasShifted: false,
            subtasks: nested,
          ),
        );
        cursor = end;
      }
      return result;
    }

    DateTime? cursor;
    final scheduled = <ScheduledTask>[];
    for (final task in roots) {
      final stats = statsFor(task);
      final completion = task.completions[dateKey(date)];
      late DateTime start;
      late DateTime end;
      var wasShifted = false;

      if (completion != null) {
        start = completion.scheduledStart;
        end = completion.scheduledEnd;
        final completionCursor = maxDateTime(completion.scheduledEnd, start);
        cursor = cursor == null
            ? completionCursor
            : maxDateTime(cursor, completionCursor);
      } else {
        final preferred = atMinute(date, task.startMinute);
        if (cursor == null) {
          start = preferred;
        } else if (task.isStartPinned) {
          wasShifted = preferred.isBefore(cursor);
          start = wasShifted ? cursor : preferred;
        } else {
          start = cursor;
        }
        end = start.add(stats.expectedDuration);
        cursor = end;
      }

      scheduled.add(
        ScheduledTask(
          task: task,
          occurrenceDate: date,
          start: start,
          end: end,
          stats: stats,
          isCompleted: completion != null,
          wasShifted: wasShifted,
          subtasks: scheduleChildren(task, start, completion != null),
        ),
      );
    }

    final dayStats = PertStats.chain(scheduled.map((value) => value.stats));
    DateTime? projectedFinish;
    for (final item in scheduled) {
      projectedFinish = projectedFinish == null
          ? item.end
          : maxDateTime(projectedFinish, item.end);
    }
    return DaySchedule(
      date: date,
      tasks: scheduled,
      stats: dayStats,
      projectedFinish: projectedFinish,
    );
  }

  static int _byOrder(PlannerTask a, PlannerTask b) {
    final order = a.order.compareTo(b.order);
    return order != 0 ? order : a.createdAt.compareTo(b.createdAt);
  }
}
