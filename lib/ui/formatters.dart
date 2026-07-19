import 'package:intl/intl.dart';

import '../models/planner_task.dart';

final DateFormat _time = DateFormat('h:mm a');
final DateFormat _dayHeader = DateFormat('EEE, d MMM');
final DateFormat _longDate = DateFormat('EEEE, d MMMM yyyy');
final DateFormat _month = DateFormat('MMMM yyyy');

String formatTime(DateTime value) => _time.format(value);
String formatDayHeader(DateTime value) => _dayHeader.format(value);
String formatLongDate(DateTime value) => _longDate.format(value);
String formatMonth(DateTime value) => _month.format(value);

String formatNumber(double value) {
  if ((value - value.round()).abs() < 0.05) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

String formatMinutes(double minutes) {
  final rounded = minutes.round();
  if (rounded < 60) {
    return '${rounded}m';
  }
  final hours = rounded ~/ 60;
  final remainder = rounded % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

String formatClockDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.abs();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String repeatLabel(PlannerTask task) => switch (task.repeatRule.kind) {
  RepeatKind.none => 'Does not repeat',
  RepeatKind.daily => 'Daily',
  RepeatKind.weekly => _weeklyLabel(task.repeatRule.weekdays),
  RepeatKind.monthly => 'Monthly on day ${task.anchorDate.day}',
};

String _weeklyLabel(Set<int> weekdays) {
  if (weekdays.isEmpty) {
    return 'Weekly';
  }
  const labels = <int, String>{
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
  };
  final sorted = weekdays.toList()..sort();
  return 'Weekly · ${sorted.map((day) => labels[day]).join(', ')}';
}
