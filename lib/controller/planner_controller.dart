import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../domain/date_keys.dart';
import '../domain/streak_calculator.dart';
import '../domain/timeline_engine.dart';
import '../models/pert.dart';
import '../models/planner_task.dart';
import '../services/alarm_service_contract.dart';
import '../services/task_storage_contract.dart';

class ActionResult {
  const ActionResult.success([this.message]) : isSuccess = true;
  const ActionResult.failure(this.message) : isSuccess = false;

  final bool isSuccess;
  final String? message;
}

class PlannerController extends ChangeNotifier {
  PlannerController({
    required TaskStorage storage,
    required AlarmScheduler alarms,
    TimelineEngine? timelineEngine,
  }) : _storage = storage,
       _alarms = alarms,
       _timelineEngine = timelineEngine ?? TimelineEngine();

  static const int _alarmHorizonDays = 30;
  static const int _maxPendingAlarms = 450;

  final TaskStorage _storage;
  final AlarmScheduler _alarms;
  final TimelineEngine _timelineEngine;
  final Uuid _uuid = const Uuid();

  List<PlannerTask> _tasks = const <PlannerTask>[];
  DateTime _selectedDate = dateOnly(DateTime.now());
  bool _isLoading = true;
  ThemeMode _themeMode = ThemeMode.system;
  String? _errorMessage;
  String? _alarmMessage;
  bool _alarmMessageIsError = false;
  bool _alarmsSupported = false;
  bool _alarmsReady = false;

  List<PlannerTask> get tasks => List<PlannerTask>.unmodifiable(_tasks);
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeMode;
  String? get errorMessage => _errorMessage;
  String? get alarmMessage => _alarmMessage;
  bool get alarmMessageIsError => _alarmMessageIsError;
  bool get alarmsSupported => _alarmsSupported;
  bool get alarmsReady => _alarmsReady;

  List<PlannerTask> get repeatingTasks =>
      _tasks.where((task) => task.parentId == null && task.isRepeating).toList()
        ..sort(_byOrder);

  Future<void> initialize() async {
    try {
      _tasks = List<PlannerTask>.unmodifiable(await _storage.loadTasks());
    } catch (error) {
      _errorMessage = 'Could not load saved planner data: $error';
    }

    final alarmResult = await _alarms.initializeAndRequestPermissions();
    _applyAlarmResult(alarmResult);
    _isLoading = false;
    notifyListeners();
    if (_tasks.isNotEmpty && alarmResult.isReady) {
      await _refreshAlarms();
    }
  }

  void selectDate(DateTime date) {
    _selectedDate = dateOnly(date);
    notifyListeners();
  }

  void changeDay(int days) =>
      selectDate(_selectedDate.add(Duration(days: days)));

  void toggleTheme() {
    _themeMode = switch (_themeMode) {
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.system => ThemeMode.dark,
    };
    notifyListeners();
  }

  void dismissError() {
    _errorMessage = null;
    notifyListeners();
  }

  void dismissAlarmMessage() {
    _alarmMessage = null;
    notifyListeners();
  }

  DaySchedule scheduleFor(DateTime date) => _timelineEngine.build(_tasks, date);

  PlannerTask? taskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  List<PlannerTask> childrenOf(String parentId) =>
      _tasks.where((task) => task.parentId == parentId).toList()
        ..sort(_byOrder);

  String createId() => _uuid.v4();

  int nextOrder({String? parentId}) {
    final siblings = _tasks.where((task) => task.parentId == parentId);
    if (siblings.isEmpty) {
      return 100;
    }
    return siblings.map((task) => task.order).reduce(math.max) + 100;
  }

  DateTime suggestedStart(DateTime date) {
    final schedule = scheduleFor(date);
    if (schedule.projectedFinish case final finish?) {
      return finish;
    }
    if (isSameDate(date, DateTime.now())) {
      final now = DateTime.now();
      final roundedMinute = ((now.minute + 4) ~/ 5) * 5;
      return DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
      ).add(Duration(minutes: roundedMinute));
    }
    return atMinute(date, 9 * 60);
  }

  PertStats statsForTask(PlannerTask task) {
    final children = childrenOf(task.id);
    if (children.isEmpty) {
      return PertStats.fromEstimate(task.estimate);
    }
    return PertStats.chain(children.map(statsForTask));
  }

  StreakStats streakFor(PlannerTask task, [DateTime? now]) =>
      StreakCalculator.calculate(task, now ?? DateTime.now());

  Future<ActionResult> saveTask(
    PlannerTask task, {
    DateTime? occurrenceDate,
  }) async {
    if (task.title.trim().isEmpty) {
      return const ActionResult.failure('Task title is required.');
    }
    final estimateError = task.estimate.validationError;
    if (estimateError != null) {
      return ActionResult.failure(estimateError);
    }
    if (task.startMinute < 0 || task.startMinute >= 24 * 60) {
      return const ActionResult.failure('Choose a valid start time.');
    }
    if (task.parentId == task.id || _wouldCreateParentCycle(task)) {
      return const ActionResult.failure('A task cannot contain itself.');
    }

    final next = List<PlannerTask>.from(_tasks);
    final index = next.indexWhere((value) => value.id == task.id);
    if (index == -1) {
      next.add(task);
    } else {
      next[index] = task;
    }

    if (task.parentId == null && task.isStartPinned) {
      final validationDate = dateOnly(occurrenceDate ?? task.anchorDate);
      if (task.occursOn(validationDate)) {
        final occurrence = _timelineEngine
            .build(next, validationDate)
            .tasks
            .where((item) => item.task.id == task.id)
            .firstOrNull;
        if (occurrence?.wasShifted ?? false) {
          return const ActionResult.failure(
            'That fixed start overlaps the previous task. Pick a later time or use Auto-chain.',
          );
        }
      }
    }
    return _commit(next);
  }

  Future<ActionResult> deleteTask(String taskId) async {
    final toDelete = <String>{taskId};
    var added = true;
    while (added) {
      added = false;
      for (final task in _tasks) {
        if (task.parentId != null &&
            toDelete.contains(task.parentId) &&
            toDelete.add(task.id)) {
          added = true;
        }
      }
    }
    return _commit(
      _tasks.where((task) => !toDelete.contains(task.id)).toList(),
    );
  }

  Future<ActionResult> toggleComplete(PlannerTask task, DateTime date) async {
    if (task.parentId != null) {
      return const ActionResult.failure(
        'Complete the parent task; subtasks are tracked as its PERT chain.',
      );
    }
    final normalized = dateOnly(date);
    if (normalized.isAfter(dateOnly(DateTime.now()))) {
      return const ActionResult.failure(
        'A future task cannot be completed yet.',
      );
    }
    final key = dateKey(normalized);
    final completions = Map<String, CompletionRecord>.from(task.completions);
    if (completions.containsKey(key)) {
      completions.remove(key);
    } else {
      final occurrence = scheduleFor(
        normalized,
      ).tasks.where((item) => item.task.id == task.id).firstOrNull;
      if (occurrence == null) {
        return const ActionResult.failure(
          'This task is not scheduled on that day.',
        );
      }
      completions[key] = CompletionRecord(
        completedAt: DateTime.now(),
        scheduledStart: occurrence.start,
        scheduledEnd: occurrence.end,
      );
    }
    return saveTask(
      task.copyWith(completions: completions),
      occurrenceDate: normalized,
    );
  }

  Future<ActionResult> reorderDay(
    DateTime date,
    int oldIndex,
    int newIndex,
  ) async {
    final schedule = scheduleFor(date);
    if (oldIndex < 0 || oldIndex >= schedule.tasks.length) {
      return const ActionResult.failure('That task could not be reordered.');
    }
    if (newIndex > oldIndex) {
      newIndex--;
    }
    if (newIndex < 0 ||
        newIndex >= schedule.tasks.length ||
        newIndex == oldIndex) {
      return const ActionResult.success();
    }
    final low = math.min(oldIndex, newIndex);
    final high = math.max(oldIndex, newIndex);
    if (schedule.tasks.sublist(low, high + 1).any((item) => item.isCompleted)) {
      return const ActionResult.failure(
        'Completed tasks stay fixed. Drag only within the unfinished section.',
      );
    }

    final reorderedIds = schedule.tasks.map((item) => item.task.id).toList();
    final moved = reorderedIds.removeAt(oldIndex);
    reorderedIds.insert(newIndex, moved);
    final dayIds = reorderedIds.toSet();

    final roots = _tasks.where((task) => task.parentId == null).toList()
      ..sort(_byOrder);
    final slots = <int>[];
    for (var index = 0; index < roots.length; index++) {
      if (dayIds.contains(roots[index].id)) {
        slots.add(index);
      }
    }
    final byId = <String, PlannerTask>{for (final task in roots) task.id: task};
    for (var index = 0; index < slots.length; index++) {
      roots[slots[index]] = byId[reorderedIds[index]]!;
    }
    final updatedRoots = <String, PlannerTask>{};
    for (var index = 0; index < roots.length; index++) {
      updatedRoots[roots[index].id] = roots[index].copyWith(
        order: (index + 1) * 100,
      );
    }
    final next = _tasks
        .map((task) => updatedRoots[task.id] ?? task)
        .toList(growable: false);
    return _commit(next);
  }

  Future<ActionResult> postponeToTomorrow(
    PlannerTask task,
    DateTime occurrenceDate,
  ) async {
    if (task.parentId != null) {
      return const ActionResult.failure('Postpone the parent task instead.');
    }
    final date = dateOnly(occurrenceDate);
    if (task.isCompletedOn(date)) {
      return const ActionResult.failure(
        'A completed task cannot be postponed.',
      );
    }
    final tomorrow = date.add(const Duration(days: 1));
    final next = List<PlannerTask>.from(_tasks);

    if (!task.isRepeating) {
      final index = next.indexWhere((value) => value.id == task.id);
      next[index] = task.copyWith(
        anchorDate: tomorrow,
        isStartPinned: false,
        order: nextOrder(),
      );
      return _commit(next);
    }

    final skipped = Set<String>.from(task.skippedDates)..add(dateKey(date));
    final rootIndex = next.indexWhere((value) => value.id == task.id);
    next[rootIndex] = task.copyWith(skippedDates: skipped);

    final descendants = <PlannerTask>[];
    void collect(String parentId) {
      for (final child in _tasks.where((value) => value.parentId == parentId)) {
        descendants.add(child);
        collect(child.id);
      }
    }

    collect(task.id);
    final idMap = <String, String>{task.id: createId()};
    for (final descendant in descendants) {
      idMap[descendant.id] = createId();
    }
    next.add(
      task.copyWith(
        id: idMap[task.id],
        anchorDate: tomorrow,
        isStartPinned: false,
        repeatRule: const RepeatRule(),
        order: nextOrder(),
        completions: const <String, CompletionRecord>{},
        skippedDates: const <String>{},
        parentId: null,
        createdAt: DateTime.now(),
      ),
    );
    for (final descendant in descendants) {
      next.add(
        descendant.copyWith(
          id: idMap[descendant.id],
          parentId: idMap[descendant.parentId],
          anchorDate: tomorrow,
          repeatRule: const RepeatRule(),
          completions: const <String, CompletionRecord>{},
          skippedDates: const <String>{},
          createdAt: DateTime.now(),
        ),
      );
    }
    return _commit(next);
  }

  Future<ActionResult> retryAlarmPermissions() async {
    final result = await _alarms.initializeAndRequestPermissions();
    _applyAlarmResult(result);
    notifyListeners();
    if (result.isReady) {
      final warning = await _refreshAlarms();
      return warning == null
          ? const ActionResult.success('Alarms are ready.')
          : ActionResult.success(warning);
    }
    return ActionResult.failure(
      result.message ?? 'Exact alarm permission is still disabled.',
    );
  }

  bool _wouldCreateParentCycle(PlannerTask task) {
    var parentId = task.parentId;
    final visited = <String>{task.id};
    while (parentId != null) {
      if (!visited.add(parentId)) {
        return true;
      }
      parentId = taskById(parentId)?.parentId;
    }
    return false;
  }

  Future<ActionResult> _commit(List<PlannerTask> next) async {
    final previous = _tasks;
    _tasks = List<PlannerTask>.unmodifiable(next);
    _errorMessage = null;
    notifyListeners();
    try {
      await _storage.saveTasks(_tasks);
    } catch (error) {
      _tasks = previous;
      _errorMessage =
          'Nothing was changed because local storage failed: $error';
      notifyListeners();
      return ActionResult.failure(_errorMessage!);
    }

    final alarmWarning = await _refreshAlarms();
    return ActionResult.success(alarmWarning);
  }

  Future<String?> _refreshAlarms() async {
    if (!_alarmsSupported || !_alarmsReady) {
      return _alarmMessageIsError ? _alarmMessage : null;
    }
    final now = DateTime.now();
    final today = dateOnly(now);
    final entries = <AlarmEntry>[];
    var truncated = false;

    outer:
    for (var offset = 0; offset < _alarmHorizonDays; offset++) {
      final date = today.add(Duration(days: offset));
      for (final root in scheduleFor(date).tasks) {
        for (final item in root.flattened) {
          if (item.isCompleted) {
            continue;
          }
          for (final phase in <({DateTime at, bool isStart})>[
            (at: item.start, isStart: true),
            (at: item.end, isStart: false),
          ]) {
            if (!phase.at.isAfter(now)) {
              continue;
            }
            if (entries.length >= _maxPendingAlarms) {
              truncated = true;
              break outer;
            }
            final phaseName = phase.isStart ? 'start' : 'end';
            entries.add(
              AlarmEntry(
                id: _notificationId('${item.occurrenceId}:$phaseName'),
                at: phase.at,
                title: phase.isStart
                    ? 'Start: ${item.task.title}'
                    : 'Time’s up: ${item.task.title}',
                body: phase.isStart
                    ? 'Your PERT-planned task starts now.'
                    : 'The expected PERT duration has finished.',
                payload: item.occurrenceId,
              ),
            );
          }
        }
      }
    }

    final result = await _alarms.replaceAll(entries);
    _applyAlarmResult(result);
    if (result.isReady && truncated) {
      _alarmMessage =
          'Alarm capacity reached. The nearest $_maxPendingAlarms reminders are scheduled; open the app periodically to extend the horizon.';
      _alarmMessageIsError = true;
    }
    notifyListeners();
    return _alarmMessageIsError ? _alarmMessage : null;
  }

  void _applyAlarmResult(AlarmResult result) {
    _alarmsSupported = result.isSupported;
    _alarmsReady = result.isReady;
    _alarmMessage = result.message;
    _alarmMessageIsError = result.isSupported && !result.isReady;
  }

  static int _notificationId(String input) {
    var hash = 0x811c9dc5;
    for (final value in input.codeUnits) {
      hash ^= value;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static int _byOrder(PlannerTask a, PlannerTask b) {
    final order = a.order.compareTo(b.order);
    return order != 0 ? order : a.createdAt.compareTo(b.createdAt);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
