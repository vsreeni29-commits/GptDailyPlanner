import 'package:flutter/widgets.dart';

import 'planner_controller.dart';

class PlannerScope extends InheritedNotifier<PlannerController> {
  const PlannerScope({
    required PlannerController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static PlannerController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlannerScope>();
    assert(scope != null, 'PlannerScope was not found above this context.');
    return scope!.notifier!;
  }
}
