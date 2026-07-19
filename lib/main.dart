import 'package:flutter/material.dart';

import 'app.dart';
import 'controller/planner_controller.dart';
import 'services/alarm_service.dart';
import 'services/task_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    PertPlannerApp(
      controller: PlannerController(
        storage: createTaskStorage(),
        alarms: createAlarmScheduler(),
      ),
    ),
  );
}
