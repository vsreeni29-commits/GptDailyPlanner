import '../models/planner_task.dart';

abstract interface class TaskStorage {
  Future<List<PlannerTask>> loadTasks();
  Future<void> saveTasks(List<PlannerTask> tasks);
}
