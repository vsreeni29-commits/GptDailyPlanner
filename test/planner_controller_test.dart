import 'package:flutter_test/flutter_test.dart';
import 'package:pert_daily_planner/controller/planner_controller.dart';
import 'package:pert_daily_planner/models/pert.dart';
import 'package:pert_daily_planner/models/planner_task.dart';
import 'package:pert_daily_planner/services/alarm_service_contract.dart';
import 'package:pert_daily_planner/services/task_storage_contract.dart';

void main() {
  test('alarm failure is visible but never rolls back a saved task', () async {
    final storage = MemoryStorage();
    final controller = PlannerController(
      storage: storage,
      alarms: FailingAlarmScheduler(),
    );
    await controller.initialize();
    final date = DateTime.now();
    final result = await controller.saveTask(makeTask(date));

    expect(result.isSuccess, isTrue);
    expect(storage.tasks, hasLength(1));
    expect(controller.tasks, hasLength(1));
    expect(result.message, contains('could not refresh'));
    expect(controller.alarmMessageIsError, isTrue);
  });

  test('storage failure rolls back the optimistic update', () async {
    final storage = MemoryStorage(throwOnSave: true);
    final controller = PlannerController(
      storage: storage,
      alarms: ReadyAlarmScheduler(),
    );
    await controller.initialize();
    final result = await controller.saveTask(makeTask(DateTime.now()));

    expect(result.isSuccess, isFalse);
    expect(controller.tasks, isEmpty);
    expect(controller.errorMessage, contains('Nothing was changed'));
  });
}

PlannerTask makeTask(DateTime date) => PlannerTask(
  id: 'task',
  title: 'Task',
  notes: '',
  anchorDate: date,
  startMinute: 23 * 60,
  isStartPinned: false,
  estimate: const PertEstimate(optimistic: 10, mostLikely: 20, pessimistic: 30),
  repeatRule: const RepeatRule(),
  order: 100,
  createdAt: date,
);

class MemoryStorage implements TaskStorage {
  MemoryStorage({this.throwOnSave = false});

  final bool throwOnSave;
  List<PlannerTask> tasks = <PlannerTask>[];

  @override
  Future<List<PlannerTask>> loadTasks() async => List<PlannerTask>.from(tasks);

  @override
  Future<void> saveTasks(List<PlannerTask> tasks) async {
    if (throwOnSave) {
      throw StateError('disk full');
    }
    this.tasks = List<PlannerTask>.from(tasks);
  }
}

class FailingAlarmScheduler implements AlarmScheduler {
  @override
  Future<AlarmResult> initializeAndRequestPermissions() async =>
      const AlarmResult(isSupported: true, isReady: true);

  @override
  Future<AlarmResult> replaceAll(List<AlarmEntry> entries) async =>
      const AlarmResult(
        isSupported: true,
        isReady: false,
        message: 'Tasks were saved, but alarms could not refresh.',
      );
}

class ReadyAlarmScheduler implements AlarmScheduler {
  @override
  Future<AlarmResult> initializeAndRequestPermissions() async =>
      const AlarmResult(isSupported: true, isReady: true);

  @override
  Future<AlarmResult> replaceAll(List<AlarmEntry> entries) async =>
      const AlarmResult(isSupported: true, isReady: true);
}
