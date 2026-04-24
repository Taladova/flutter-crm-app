import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/task_model.dart';
import '../../../data/repositories/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return const TaskRepository();
});

final taskControllerProvider =
    AsyncNotifierProvider<TaskController, List<TaskModel>>(
  TaskController.new,
);

final tasksByProjectProvider = Provider.family<List<TaskModel>, String>(
  (ref, projectId) {
    final tasksState = ref.watch(taskControllerProvider);

    return tasksState.when(
      data: (tasks) {
        return tasks.where((task) => task.projectId == projectId).toList();
      },
      loading: () => [],
      error: (_, __) => [],
    );
  },
);

class TaskController extends AsyncNotifier<List<TaskModel>> {
  @override
  Future<List<TaskModel>> build() async {
    final repository = ref.watch(taskRepositoryProvider);
    return repository.getTasks();
  }

  Future<void> addTask(TaskModel task) async {
    final currentTasks = state.value ?? [];

    final updatedTasks = [
      task,
      ...currentTasks,
    ];

    state = AsyncValue.data(updatedTasks);

    await ref.read(taskRepositoryProvider).saveTasks(updatedTasks);
  }

  Future<void> toggleTaskStatus(TaskModel selectedTask) async {
    final currentTasks = state.value ?? [];

    final updatedTasks = currentTasks.map((task) {
      if (task.id == selectedTask.id) {
        final isDone = task.status == 'Terminé';

        return task.copyWith(
          status: isDone ? 'À faire' : 'Terminé',
        );
      }

      return task;
    }).toList();

    state = AsyncValue.data(updatedTasks);

    await ref.read(taskRepositoryProvider).saveTasks(updatedTasks);
  }
}