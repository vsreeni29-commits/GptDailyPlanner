import '../domain/date_keys.dart';
import 'pert.dart';

enum RepeatKind { none, daily, weekly, monthly }

class RepeatRule {
  const RepeatRule({
    this.kind = RepeatKind.none,
    this.weekdays = const <int>{},
  });

  final RepeatKind kind;
  final Set<int> weekdays;

  bool occursOn(DateTime anchor, DateTime candidate) {
    final start = dateOnly(anchor);
    final date = dateOnly(candidate);
    if (date.isBefore(start)) {
      return false;
    }
    return switch (kind) {
      RepeatKind.none => isSameDate(start, date),
      RepeatKind.daily => true,
      RepeatKind.weekly =>
        (weekdays.isEmpty ? <int>{start.weekday} : weekdays).contains(
          date.weekday,
        ),
      RepeatKind.monthly =>
        date.day == start.day.clamp(1, daysInMonth(date.year, date.month)),
    };
  }

  Map<String, Object> toJson() => <String, Object>{
    'kind': kind.name,
    'weekdays': weekdays.toList()..sort(),
  };

  factory RepeatRule.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const RepeatRule();
    }
    final name = json['kind'] as String? ?? RepeatKind.none.name;
    final kind = RepeatKind.values.firstWhere(
      (value) => value.name == name,
      orElse: () => RepeatKind.none,
    );
    return RepeatRule(
      kind: kind,
      weekdays: ((json['weekdays'] as List<dynamic>?) ?? const <dynamic>[])
          .map((value) => (value as num).toInt())
          .where(
            (value) => value >= DateTime.monday && value <= DateTime.sunday,
          )
          .toSet(),
    );
  }
}

class CompletionRecord {
  const CompletionRecord({
    required this.completedAt,
    required this.scheduledStart,
    required this.scheduledEnd,
  });

  final DateTime completedAt;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;

  Map<String, String> toJson() => <String, String>{
    'completedAt': completedAt.toIso8601String(),
    'scheduledStart': scheduledStart.toIso8601String(),
    'scheduledEnd': scheduledEnd.toIso8601String(),
  };

  factory CompletionRecord.fromJson(Map<String, dynamic> json) =>
      CompletionRecord(
        completedAt: DateTime.parse(json['completedAt'] as String),
        scheduledStart: DateTime.parse(json['scheduledStart'] as String),
        scheduledEnd: DateTime.parse(json['scheduledEnd'] as String),
      );
}

class PlannerTask {
  const PlannerTask({
    required this.id,
    required this.title,
    required this.notes,
    required this.anchorDate,
    required this.startMinute,
    required this.isStartPinned,
    required this.estimate,
    required this.repeatRule,
    required this.order,
    required this.createdAt,
    this.parentId,
    this.completions = const <String, CompletionRecord>{},
    this.skippedDates = const <String>{},
  });

  static const Object _notSet = Object();

  final String id;
  final String title;
  final String notes;
  final DateTime anchorDate;
  final int startMinute;
  final bool isStartPinned;
  final PertEstimate estimate;
  final RepeatRule repeatRule;
  final int order;
  final DateTime createdAt;
  final String? parentId;
  final Map<String, CompletionRecord> completions;
  final Set<String> skippedDates;

  bool get isRepeating => repeatRule.kind != RepeatKind.none;

  bool occursOn(DateTime date) =>
      !skippedDates.contains(dateKey(date)) &&
      repeatRule.occursOn(anchorDate, date);

  bool isCompletedOn(DateTime date) => completions.containsKey(dateKey(date));

  PlannerTask copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? anchorDate,
    int? startMinute,
    bool? isStartPinned,
    PertEstimate? estimate,
    RepeatRule? repeatRule,
    int? order,
    DateTime? createdAt,
    Object? parentId = _notSet,
    Map<String, CompletionRecord>? completions,
    Set<String>? skippedDates,
  }) => PlannerTask(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    anchorDate: dateOnly(anchorDate ?? this.anchorDate),
    startMinute: startMinute ?? this.startMinute,
    isStartPinned: isStartPinned ?? this.isStartPinned,
    estimate: estimate ?? this.estimate,
    repeatRule: repeatRule ?? this.repeatRule,
    order: order ?? this.order,
    createdAt: createdAt ?? this.createdAt,
    parentId: identical(parentId, _notSet)
        ? this.parentId
        : parentId as String?,
    completions: completions ?? this.completions,
    skippedDates: skippedDates ?? this.skippedDates,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'notes': notes,
    'anchorDate': dateKey(anchorDate),
    'startMinute': startMinute,
    'isStartPinned': isStartPinned,
    'estimate': estimate.toJson(),
    'repeatRule': repeatRule.toJson(),
    'order': order,
    'createdAt': createdAt.toIso8601String(),
    'parentId': parentId,
    'completions': completions.map(
      (key, value) => MapEntry<String, Object>(key, value.toJson()),
    ),
    'skippedDates': skippedDates.toList()..sort(),
  };

  factory PlannerTask.fromJson(Map<String, dynamic> json) {
    final completionJson =
        (json['completions'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    return PlannerTask(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String? ?? '',
      anchorDate: dateFromKey(json['anchorDate'] as String),
      startMinute: (json['startMinute'] as num).toInt(),
      isStartPinned: json['isStartPinned'] as bool? ?? false,
      estimate: PertEstimate.fromJson(
        Map<String, dynamic>.from(json['estimate'] as Map<dynamic, dynamic>),
      ),
      repeatRule: RepeatRule.fromJson(
        json['repeatRule'] == null
            ? null
            : Map<String, dynamic>.from(
                json['repeatRule'] as Map<dynamic, dynamic>,
              ),
      ),
      order: (json['order'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      parentId: json['parentId'] as String?,
      completions: completionJson.map<String, CompletionRecord>(
        (key, value) => MapEntry<String, CompletionRecord>(
          key as String,
          CompletionRecord.fromJson(
            Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
          ),
        ),
      ),
      skippedDates:
          ((json['skippedDates'] as List<dynamic>?) ?? const <dynamic>[])
              .cast<String>()
              .toSet(),
    );
  }
}
