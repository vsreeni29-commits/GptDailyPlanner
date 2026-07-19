import 'package:flutter/material.dart';

import '../../controller/planner_scope.dart';
import '../dialogs/task_editor.dart';
import '../widgets/status_banner.dart';
import 'calendar_view.dart';
import 'day_view.dart';
import 'streaks_view.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('PERT Daily Planner'),
            Text(
              'Estimate · chain · finish with confidence',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Toggle light/dark theme',
            onPressed: controller.toggleTheme,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (controller.errorMessage case final message?)
            StatusBanner(
              message: message,
              isError: true,
              onDismiss: controller.dismissError,
            ),
          if (controller.alarmMessage case final message?)
            StatusBanner(
              message: message,
              isError: controller.alarmMessageIsError,
              onDismiss: controller.dismissAlarmMessage,
              onRetry: controller.alarmsSupported && !controller.alarmsReady
                  ? () async {
                      final result = await controller.retryAlarmPermissions();
                      if (context.mounted && result.message != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message!)),
                        );
                      }
                    }
                  : null,
            ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: <Widget>[
                const DayView(),
                CalendarView(onOpenDay: () => setState(() => _index = 0)),
                const StreaksView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: () => TaskEditor.show(
                context,
                selectedDate: controller.selectedDate,
                suggestedStart: controller.suggestedStart(
                  controller.selectedDate,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add task'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.view_timeline_outlined),
            selectedIcon: Icon(Icons.view_timeline_rounded),
            label: 'Day',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded),
            label: 'Streaks',
          ),
        ],
      ),
    );
  }
}
