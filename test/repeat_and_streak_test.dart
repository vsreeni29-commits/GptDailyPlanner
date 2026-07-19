import 'package:flutter_test/flutter_test.dart';
import 'package:pert_daily_planner/domain/date_keys.dart';
import 'package:pert_daily_planner/domain/streak_calculator.dart';
import 'package:pert_daily_planner/models/pert.dart';
import 'package:pert_daily_planner/models/planner_task.dart';

void main() {
  group('RepeatRule', () {
    test('weekly repeats honor selected weekdays', () {
      const rule = RepeatRule(
        kind: RepeatKind.weekly,
        weekdays: <int>{DateTime.monday, DateTime.wednesday},
      );
      final anchor = DateTime(2026, 7, 6);

      expect(rule.occursOn(anchor, DateTime(2026, 7, 13)), isTrue);
      expect(rule.occursOn(anchor, DateTime(2026, 7, 14)), isFalse);
      expect(rule.occursOn(anchor, DateTime(2026, 7, 15)), isTrue);
    });

    test('monthly repeats clamp to the last calendar day', () {
      const rule = RepeatRule(kind: RepeatKind.monthly);
      final anchor = DateTime(2024, 1, 31);

      expect(rule.occursOn(anchor, DateTime(2024, 2, 29)), isTrue);
      expect(rule.occursOn(anchor, DateTime(2024, 3, 31)), isTrue);
      expect(rule.occursOn(anchor, DateTime(2024, 3, 30)), isFalse);
    });
  });

  test('streaks count scheduled completions and expose seven days', () {
    final today = DateTime(2026, 7, 19);
    final completions = <String, CompletionRecord>{};
    for (var offset = 2; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      completions[dateKey(day)] = CompletionRecord(
        completedAt: day.add(const Duration(hours: 9)),
        scheduledStart: day.add(const Duration(hours: 9)),
        scheduledEnd: day.add(const Duration(hours: 9, minutes: 30)),
      );
    }
    final repeating = PlannerTask(
      id: 'daily',
      title: 'Daily practice',
      notes: '',
      anchorDate: today.subtract(const Duration(days: 5)),
      startMinute: 9 * 60,
      isStartPinned: false,
      estimate: const PertEstimate(
        optimistic: 20,
        mostLikely: 30,
        pessimistic: 40,
      ),
      repeatRule: const RepeatRule(kind: RepeatKind.daily),
      order: 100,
      createdAt: DateTime(2026),
      completions: completions,
    );

    final stats = StreakCalculator.calculate(repeating, today);
    expect(stats.current, 3);
    expect(stats.best, 3);
    expect(stats.lastSevenDays, hasLength(7));
    expect(stats.lastSevenDays.last.isComplete, isTrue);
  });
}
