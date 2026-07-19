import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/planner_task.dart';
import 'task_storage_contract.dart';

TaskStorage createTaskStorage() => MobileTaskStorage();

class MobileTaskStorage implements TaskStorage {
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    final path = p.join(await getDatabasesPath(), 'pert_daily_planner.db');
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE planner_state('
        'slot INTEGER PRIMARY KEY, '
        'payload TEXT NOT NULL'
        ')',
      ),
    );
    _database = database;
    return database;
  }

  @override
  Future<List<PlannerTask>> loadTasks() async {
    final rows = await (await _db).query(
      'planner_state',
      columns: <String>['payload'],
      where: 'slot = ?',
      whereArgs: <Object>[1],
      limit: 1,
    );
    if (rows.isEmpty) {
      return <PlannerTask>[];
    }
    final decoded =
        jsonDecode(rows.single['payload']! as String) as List<dynamic>;
    return decoded
        .map(
          (value) => PlannerTask.fromJson(
            Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveTasks(List<PlannerTask> tasks) async {
    final payload = jsonEncode(tasks.map((task) => task.toJson()).toList());
    await (await _db).insert('planner_state', <String, Object>{
      'slot': 1,
      'payload': payload,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
