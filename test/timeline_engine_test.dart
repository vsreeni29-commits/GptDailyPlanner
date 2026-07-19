import 'package:flutter_test/flutter_test.dart';
import 'package:pert_daily_planner/domain/date_keys.dart';
import 'package:pert_daily_planner/domain/timeline_engine.dart';
import 'package:pert_daily_planner/models/pert.dart';
import 'package:pert_daily_planner/models/planner_task.dart';

void main() {
  final date = DateTime(2026, 7, 19);

  group('TimelineEngine', () {
    test('chains unfinished tasks back-to-back', () {
      final schedule = TimelineEngine().build(<PlannerTask>[
        task(id: 'a', date: date, startMinute: 9 * 60, order: 100),
        task(id: 'b', date: date, startMinute: 8 * 60, order: 200),
      ], date);

      expect(schedule.tasks[0].start, DateTime(2026, 7, 19, 9));
      expect(schedule.tasks[0].end, DateTime(2026, 7, 19, 9, 30));
      expect(schedule.tasks[1].start, schedule.tasks[0].end);
      expect(schedule.tasks[1].end, DateTime(2026, 7, 19, 10));
    });

    test('respects a later fixed start and flags a conflicting one', () {
      final schedule = TimelineEngine().build(<PlannerTask>[
        task(id: 'a', date: date, startMinute: 9 * 60, order: 100),
        task(
          id: 'b',
          date: date,
          startMinute: 10 * 60,
          order: 200,
          pinned: true,
        ),
        task(
          id: 'c',
          date: date,
          startMinute: 9 * 60,
          order: 300,
          pinned: true,
        ),
      ], date);

      expect(schedule.tasks[1].start, DateTime(2026, 7, 19, 10));
      expect(schedule.tasks[1].wasShifted, isFalse);
      expect(schedule.tasks[2].start, DateTime(2026, 7, 19, 10, 30));
      expect(schedule.tasks[2].wasShifted, isTrue);
    });

    test('uses subtask totals for the parent chain', () {
      final schedule = TimelineEngine().build(<PlannerTask>[
        task(id: 'parent', date: date, startMinute: 9 * 60, order: 100),
        task(
          id: 'child-a',
          date: date,
          startMinute: 0,
          order: 100,
          parentId: 'parent',
          minutes: 20,
        ),
        task(
          id: 'child-b',
          date: date,
          startMinute: 0,
          order: 200,
          parentId: 'parent',
          minutes: 40,
        ),
        task(id: 'next', date: date, startMinute: 0, order: 200),
      ], date);

      final parent = schedule.tasks.first;
      expect(parent.stats.expected, 60);
      expect(parent.end, DateTime(2026, 7, 19, 10));
      expect(parent.subtasks, hasLength(2));
      expect(parent.subtasks[1].start, DateTime(2026, 7, 19, 9, 20));
      expect(schedule.tasks[1].start, DateTime(2026, 7, 19, 10));
    });

    test(
      'keeps a completed occurrence fixed and reflows from completion time',
      () {
        final originalStart = DateTime(2026, 7, 19, 9);
        final originalEnd = DateTime(2026, 7, 19, 9, 30);
        final completedAt = DateTime(2026, 7, 19, 9, 15);
        final completed =
            task(id: 'a', date: date, startMinute: 9 * 60, order: 100).copyWith(
              completions: <String, CompletionRecord>{
                dateKey(date): CompletionRecord(
                  completedAt: completedAt,
                  scheduledStart: originalStart,
                  scheduledEnd: originalEnd,
                ),
              },
            );

        final schedule = TimelineEngine().build(<PlannerTask>[
          completed,
          task(id: 'b', date: date, startMinute: 0, order: 200),
        ], date);

        expect(schedule.tasks.first.start, originalStart);
        expect(schedule.tasks.first.end, originalEnd);
        expect(schedule.tasks.first.isCompleted, isTrue);
        expect(schedule.tasks[1].start, completedAt);
      },
    );
  });
}

PlannerTask task({
  required String id,
  required DateTime date,
  required int startMinute,
  required int order,
  String? parentId,
  bool pinned = false,
  double minutes = 30,
}) => PlannerTask(
  id: id,
  title: id,
  notes: '',
  anchorDate: date,
  startMinute: startMinute,
  isStartPinned: pinned,
  estimate: PertEstimate(
    optimistic: minutes,
    mostLikely: minutes,
    pessimistic: minutes,
  ),
  repeatRule: const RepeatRule(),
  order: order,
  createdAt: DateTime(2026),
  parentId: parentId,
);
