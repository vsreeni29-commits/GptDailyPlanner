import 'package:flutter/material.dart';

import '../../controller/planner_scope.dart';
import '../../domain/date_keys.dart';
import '../formatters.dart';

enum CalendarRange { month, twoWeeks, week }

class CalendarView extends StatefulWidget {
  const CalendarView({required this.onOpenDay, super.key});

  final VoidCallback onOpenDay;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  CalendarRange _range = CalendarRange.month;
  late DateTime _focus = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    final days = _visibleDays();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          child: Column(
            children: <Widget>[
              SegmentedButton<CalendarRange>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<CalendarRange>>[
                  ButtonSegment(
                    value: CalendarRange.month,
                    label: Text('Month'),
                  ),
                  ButtonSegment(
                    value: CalendarRange.twoWeeks,
                    label: Text('2 weeks'),
                  ),
                  ButtonSegment(value: CalendarRange.week, label: Text('Week')),
                ],
                selected: <CalendarRange>{_range},
                onSelectionChanged: (value) =>
                    setState(() => _range = value.first),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Previous period',
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _title(days),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next period',
                    onPressed: () => _move(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _focus = dateOnly(DateTime.now())),
                    child: const Text('Today'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _WeekdayHeader(),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / 7;
                  final cellHeight = _range == CalendarRange.month
                      ? 92.0
                      : 112.0;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: cellWidth / cellHeight,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                    ),
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final date = days[index];
                      final schedule = controller.scheduleFor(date);
                      final completed = schedule.tasks
                          .where((task) => task.isCompleted)
                          .length;
                      return _DayCell(
                        date: date,
                        inFocusedMonth:
                            date.month == _focus.month ||
                            _range != CalendarRange.month,
                        isSelected: isSameDate(date, controller.selectedDate),
                        taskCount: schedule.tasks.length,
                        completedCount: completed,
                        onTap: () {
                          controller.selectDate(date);
                          widget.onOpenDay();
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const _LegendDot(color: Color(0xFF4F46E5)),
                  const SizedBox(width: 6),
                  Text(
                    'Scheduled',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(width: 18),
                  const _LegendDot(color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Text(
                    'Completed',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DateTime> _visibleDays() {
    switch (_range) {
      case CalendarRange.month:
        final first = DateTime(_focus.year, _focus.month);
        final last = DateTime(_focus.year, _focus.month + 1, 0);
        final start = startOfWeek(first);
        final end = startOfWeek(last).add(const Duration(days: 6));
        final count = end.difference(start).inDays + 1;
        return List<DateTime>.generate(
          count,
          (index) => start.add(Duration(days: index)),
        );
      case CalendarRange.twoWeeks:
        final start = startOfWeek(_focus);
        return List<DateTime>.generate(
          14,
          (index) => start.add(Duration(days: index)),
        );
      case CalendarRange.week:
        final start = startOfWeek(_focus);
        return List<DateTime>.generate(
          7,
          (index) => start.add(Duration(days: index)),
        );
    }
  }

  String _title(List<DateTime> days) {
    if (_range == CalendarRange.month) {
      return formatMonth(_focus);
    }
    final first = days.first;
    final last = days.last;
    return '${formatDayHeader(first)} – ${formatDayHeader(last)}';
  }

  void _move(int direction) {
    setState(() {
      _focus = switch (_range) {
        CalendarRange.month => DateTime(
          _focus.year,
          _focus.month + direction,
          1,
        ),
        CalendarRange.twoWeeks => _focus.add(Duration(days: 14 * direction)),
        CalendarRange.week => _focus.add(Duration(days: 7 * direction)),
      };
    });
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) => Row(
    children: const <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        .map(
          (label) => Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        )
        .toList(growable: false),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inFocusedMonth,
    required this.isSelected,
    required this.taskCount,
    required this.completedCount,
    required this.onTap,
  });

  final DateTime date;
  final bool inFocusedMonth;
  final bool isSelected;
  final int taskCount;
  final int completedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = isSameDate(date, DateTime.now());
    return Material(
      color: isSelected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: today ? scheme.primary : scheme.outlineVariant,
          width: today ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: inFocusedMonth ? 1 : 0.42,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: today ? scheme.primary : null,
                  ),
                ),
                const Spacer(),
                if (taskCount > 0) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      if (completedCount > 0) ...<Widget>[
                        const SizedBox(width: 3),
                        Expanded(
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$taskCount ${taskCount == 1 ? 'task' : 'tasks'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
