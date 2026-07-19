import 'dart:async';

import 'package:flutter/material.dart';

import 'controller/planner_controller.dart';
import 'controller/planner_scope.dart';
import 'theme/app_theme.dart';
import 'ui/views/home_shell.dart';

class PertPlannerApp extends StatefulWidget {
  const PertPlannerApp({required this.controller, super.key});

  final PlannerController controller;

  @override
  State<PertPlannerApp> createState() => _PertPlannerAppState();
}

class _PertPlannerAppState extends State<PertPlannerApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.controller.initialize());
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, child) => PlannerScope(
      controller: widget.controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PERT Daily Planner',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: widget.controller.themeMode,
        home: widget.controller.isLoading
            ? const _LoadingScreen()
            : const HomeShell(),
      ),
    ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.auto_graph_rounded,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          const Text('Loading your plan…'),
        ],
      ),
    ),
  );
}
