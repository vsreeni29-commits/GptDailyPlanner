import '../models/planner_task.dart';
import 'date_keys.dart';

class StreakDay {
  const StreakDay({
    required this.date,
    required this.isScheduled,
    required this.isComplete,
  });

  final DateTime date;
  final bool isScheduled;
  final bool isComplete;
}

class StreakStats {
  const StreakStats({
    required this.current,
    required this.best,
    required this.lastSevenDays,
  });

  final int current;
  final int best;
  final List<StreakDay> lastSevenDays;
}

class StreakCalculator {
  const StreakCalculator._();

  static StreakStats calculate(PlannerTask task, DateTime now) {
    final today = dateOnly(now);
    final anchor = dateOnly(task.anchorDate);
    var running = 0;
    var best = 0;
    var cursor = anchor;
    while (cursor.isBefore(today)) {
      if (task.occursOn(cursor)) {
        if (task.isCompletedOn(cursor)) {
          running++;
          if (running > best) {
            best = running;
          }
        } else {
          running = 0;
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    if (task.occursOn(today) && task.isCompletedOn(today)) {
      running++;
      if (running > best) {
        best = running;
      }
    }

    final lastSeven = List<StreakDay>.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index));
      final scheduled = task.occursOn(date);
      return StreakDay(
        date: date,
        isScheduled: scheduled,
        isComplete: scheduled && task.isCompletedOn(date),
      );
    });

    return StreakStats(current: running, best: best, lastSevenDays: lastSeven);
  }
}
