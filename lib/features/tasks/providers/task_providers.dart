import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/task_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/repositories/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
  );
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
    final updatedTasks = [task, ...currentTasks];

    state = AsyncValue.data(updatedTasks);

    await ref.read(taskRepositoryProvider).addTask(task);
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

    final updatedTask = updatedTasks.firstWhere(
      (task) => task.id == selectedTask.id,
    );

    await ref.read(taskRepositoryProvider).updateTask(updatedTask);
  }

  Future<void> resetTasks() async {
    await ref.read(taskRepositoryProvider).resetTasks();
    state = const AsyncValue.data([]);
  }
}