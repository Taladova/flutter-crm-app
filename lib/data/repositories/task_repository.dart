import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../mock/mock_tasks.dart';
import '../models/task_model.dart';

class TaskRepository {
  const TaskRepository();

  static const String _tasksKey = 'tasks';

  Future<List<TaskModel>> getTasks() async {
    await Future.delayed(const Duration(milliseconds: 400));

    final prefs = await SharedPreferences.getInstance();
    final tasksString = prefs.getString(_tasksKey);

    if (tasksString == null) {
      await saveTasks(mockTasks);
      return mockTasks;
    }

    final List<dynamic> decoded = jsonDecode(tasksString);

    return decoded
        .map((item) => TaskModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTasks(List<TaskModel> tasks) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      tasks.map((task) => task.toJson()).toList(),
    );

    await prefs.setString(_tasksKey, encoded);
  }
}