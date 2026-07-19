import 'package:flutter/material.dart';

import '../../controller/planner_controller.dart';
import '../../controller/planner_scope.dart';
import '../../domain/date_keys.dart';
import '../../models/pert.dart';
import '../../models/planner_task.dart';
import '../formatters.dart';

class TaskEditor extends StatefulWidget {
  const TaskEditor({
    required this.selectedDate,
    required this.suggestedStart,
    this.task,
    this.parentId,
    super.key,
  });

  final DateTime selectedDate;
  final DateTime suggestedStart;
  final PlannerTask? task;
  final String? parentId;

  static Future<void> show(
    BuildContext context, {
    required DateTime selectedDate,
    required DateTime suggestedStart,
    PlannerTask? task,
    String? parentId,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => TaskEditor(
      selectedDate: selectedDate,
      suggestedStart: suggestedStart,
      task: task,
      parentId: parentId,
    ),
  );

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _optimistic;
  late final TextEditingController _mostLikely;
  late final TextEditingController _pessimistic;
  late DateTime _date;
  late int _startMinute;
  late bool _startPinned;
  late RepeatKind _repeatKind;
  late Set<int> _weekdays;
  bool _saving = false;

  bool get _isSubtask => (widget.task?.parentId ?? widget.parentId) != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '');
    _notes = TextEditingController(text: task?.notes ?? '');
    _optimistic = TextEditingController(
      text: task == null ? '15' : formatNumber(task.estimate.optimistic),
    );
    _mostLikely = TextEditingController(
      text: task == null ? '25' : formatNumber(task.estimate.mostLikely),
    );
    _pessimistic = TextEditingController(
      text: task == null ? '40' : formatNumber(task.estimate.pessimistic),
    );
    _date = dateOnly(task?.anchorDate ?? widget.selectedDate);
    _startMinute =
        task?.startMinute ?? minuteOfDay(widget.suggestedStart) % (24 * 60);
    _startPinned = task?.isStartPinned ?? false;
    _repeatKind = task?.repeatRule.kind ?? RepeatKind.none;
    _weekdays = Set<int>.from(task?.repeatRule.weekdays ?? const <int>{});
    if (_repeatKind == RepeatKind.weekly && _weekdays.isEmpty) {
      _weekdays.add(_date.weekday);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _optimistic.dispose();
    _mostLikely.dispose();
    _pessimistic.dispose();
    super.dispose();
  }

  PertEstimate get _estimate => PertEstimate(
    optimistic: double.tryParse(_optimistic.text.trim()) ?? 0,
    mostLikely: double.tryParse(_mostLikely.text.trim()) ?? 0,
    pessimistic: double.tryParse(_pessimistic.text.trim()) ?? 0,
  );

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    final children = widget.task == null
        ? const <PlannerTask>[]
        : controller.childrenOf(widget.task!.id);
    final hasChildren = children.isNotEmpty;
    final stats = hasChildren
        ? controller.statsForTask(widget.task!)
        : PertStats.fromEstimate(_estimate);
    final validationError = hasChildren ? null : _estimate.validationError;
    final calculatedStart = _calculatedStart(controller);
    final calculatedEnd = calculatedStart.add(stats.expectedDuration);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final parent = controller.taskById(
      widget.task?.parentId ?? widget.parentId ?? '',
    );

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.task == null ? 'New task' : 'Edit task',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (parent != null)
                          Text(
                            'Subtask of ${parent.title}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  children: <Widget>[
                    TextFormField(
                      controller: _title,
                      autofocus: widget.task == null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                        prefixIcon: Icon(Icons.checklist_rounded),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a task title.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_isSubtask)
                      _InfoPanel(
                        icon: Icons.account_tree_outlined,
                        text:
                            'This subtask runs inside its parent. Its start and end are derived from the subtask chain.',
                      )
                    else ...<Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _PickerButton(
                              icon: Icons.calendar_today_outlined,
                              label: formatDayHeader(_date),
                              onPressed: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PickerButton(
                              icon: Icons.schedule_rounded,
                              label: _formatMinute(_startMinute),
                              onPressed: _pickTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        title: const Text('Fix this start time'),
                        subtitle: Text(
                          _startPinned
                              ? 'The task keeps this time unless it would overlap.'
                              : 'Auto-chain after the previous unfinished task.',
                        ),
                        value: _startPinned,
                        onChanged: (value) =>
                            setState(() => _startPinned = value),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Three-point estimate',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Tooltip(
                          message: 'TE = (O + 4M + P) ÷ 6',
                          child: Icon(
                            Icons.functions_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasChildren
                          ? 'Parent timing is the sum of ${children.length} subtasks; variances are added.'
                          : 'Enter durations in minutes. Required order: O ≤ M ≤ P.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _EstimateField(
                            label: 'O',
                            hint: 'Best',
                            controller: _optimistic,
                            enabled: !hasChildren,
                            onChanged: _refresh,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _EstimateField(
                            label: 'M',
                            hint: 'Likely',
                            controller: _mostLikely,
                            enabled: !hasChildren,
                            onChanged: _refresh,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _EstimateField(
                            label: 'P',
                            hint: 'Worst',
                            controller: _pessimistic,
                            enabled: !hasChildren,
                            onChanged: _refresh,
                          ),
                        ),
                      ],
                    ),
                    if (validationError != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        validationError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _LivePertPanel(
                      stats: stats,
                      start: calculatedStart,
                      end: calculatedEnd,
                      isAggregate: hasChildren,
                    ),
                    if (!_isSubtask) ...<Widget>[
                      const SizedBox(height: 20),
                      DropdownButtonFormField<RepeatKind>(
                        initialValue: _repeatKind,
                        decoration: const InputDecoration(
                          labelText: 'Repeat',
                          prefixIcon: Icon(Icons.repeat_rounded),
                        ),
                        items: RepeatKind.values
                            .map(
                              (kind) => DropdownMenuItem<RepeatKind>(
                                value: kind,
                                child: Text(switch (kind) {
                                  RepeatKind.none => 'Does not repeat',
                                  RepeatKind.daily => 'Daily',
                                  RepeatKind.weekly => 'Weekly',
                                  RepeatKind.monthly => 'Monthly',
                                }),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _repeatKind = value;
                            if (value == RepeatKind.weekly &&
                                _weekdays.isEmpty) {
                              _weekdays.add(_date.weekday);
                            }
                          });
                        },
                      ),
                      if (_repeatKind == RepeatKind.weekly) ...<Widget>[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          children: List<Widget>.generate(7, (index) {
                            final weekday = index + 1;
                            const labels = <String>[
                              'M',
                              'T',
                              'W',
                              'T',
                              'F',
                              'S',
                              'S',
                            ];
                            return FilterChip(
                              label: Text(labels[index]),
                              selected: _weekdays.contains(weekday),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _weekdays.add(weekday);
                                  } else if (_weekdays.length > 1) {
                                    _weekdays.remove(weekday);
                                  }
                                });
                              },
                            );
                          }),
                        ),
                      ],
                    ],
                    const SizedBox(height: 26),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(controller),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving…' : 'Save task'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _calculatedStart(PlannerController controller) {
    if (_isSubtask) {
      return widget.suggestedStart;
    }
    if (_startPinned) {
      return atMinute(_date, _startMinute);
    }
    if (widget.task != null && isSameDate(_date, widget.task!.anchorDate)) {
      return widget.suggestedStart;
    }
    return controller.suggestedStart(_date);
  }

  void _refresh(String _) => setState(() {});

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (mounted && picked != null) {
      setState(() => _date = dateOnly(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _startMinute ~/ 60,
        minute: _startMinute % 60,
      ),
    );
    if (mounted && picked != null) {
      setState(() {
        _startMinute = picked.hour * 60 + picked.minute;
        _startPinned = true;
      });
    }
  }

  Future<void> _save(PlannerController controller) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final estimate = _estimate;
    if (estimate.validationError != null) {
      setState(() {});
      return;
    }
    if (_repeatKind == RepeatKind.weekly && _weekdays.isEmpty) {
      _showMessage('Choose at least one weekday.');
      return;
    }

    setState(() => _saving = true);
    final existing = widget.task;
    final parentId = existing?.parentId ?? widget.parentId;
    final parent = parentId == null ? null : controller.taskById(parentId);
    final task = PlannerTask(
      id: existing?.id ?? controller.createId(),
      title: _title.text.trim(),
      notes: _notes.text.trim(),
      anchorDate: parent?.anchorDate ?? _date,
      startMinute: _isSubtask ? 0 : _startMinute,
      isStartPinned: _isSubtask ? false : _startPinned,
      estimate: estimate,
      repeatRule: _isSubtask
          ? const RepeatRule()
          : RepeatRule(kind: _repeatKind, weekdays: _weekdays),
      order: existing?.order ?? controller.nextOrder(parentId: parentId),
      createdAt: existing?.createdAt ?? DateTime.now(),
      parentId: parentId,
      completions: existing?.completions ?? const <String, CompletionRecord>{},
      skippedDates: existing?.skippedDates ?? const <String>{},
    );
    final result = await controller.saveTask(
      task,
      occurrenceDate: widget.selectedDate,
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (!result.isSuccess) {
      _showMessage(result.message ?? 'The task could not be saved.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (result.message case final warning?) {
      messenger.showSnackBar(SnackBar(content: Text(warning)));
    }
    Navigator.pop(context);
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  static String _formatMinute(int minute) {
    final date = DateTime(2000, 1, 1, minute ~/ 60, minute % 60);
    return formatTime(date);
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label, overflow: TextOverflow.ellipsis),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      alignment: Alignment.centerLeft,
    ),
  );
}

class _EstimateField extends StatelessWidget {
  const _EstimateField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.next,
    onChanged: onChanged,
    decoration: InputDecoration(labelText: '$label minutes', helperText: hint),
  );
}

class _LivePertPanel extends StatelessWidget {
  const _LivePertPanel({
    required this.stats,
    required this.start,
    required this.end,
    required this.isAggregate,
  });

  final PertStats stats;
  final DateTime start;
  final DateTime end;
  final bool isAggregate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isAggregate ? 'Live chain calculation' : 'Live PERT calculation',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: <Widget>[
              _Calculation(
                label: 'TE',
                value: '${formatNumber(stats.expected)} min',
              ),
              _Calculation(
                label: 'σ',
                value: '${formatNumber(stats.standardDeviation)} min',
              ),
              _Calculation(label: 'σ²', value: formatNumber(stats.variance)),
              _Calculation(
                label: 'Auto end',
                value: '${formatTime(start)} → ${formatTime(end)}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isAggregate
                ? 'TE values and variances add across the subtask chain.'
                : 'TE = (O + 4M + P) ÷ 6  ·  σ = (P − O) ÷ 6',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Calculation extends StatelessWidget {
  const _Calculation({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: <Widget>[
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
