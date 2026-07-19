import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/planner_task.dart';
import 'task_storage_contract.dart';

TaskStorage createTaskStorage() => WebTaskStorage();

class WebTaskStorage implements TaskStorage {
  static const _stateKey = 'pert_daily_planner_state_v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<List<PlannerTask>> loadTasks() async {
    final payload = await _preferences.getString(_stateKey);
    if (payload == null || payload.isEmpty) {
      return <PlannerTask>[];
    }
    final decoded = jsonDecode(payload) as List<dynamic>;
    return decoded
        .map(
          (value) => PlannerTask.fromJson(
            Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveTasks(List<PlannerTask> tasks) => _preferences.setString(
    _stateKey,
    jsonEncode(tasks.map((task) => task.toJson()).toList()),
  );
}
