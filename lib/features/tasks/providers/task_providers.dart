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

final taskByIdProvider = Provider.family<TaskModel?, String>(
  (ref, taskId) {
    final tasksState = ref.watch(taskControllerProvider);

    return tasksState.when(
      data: (tasks) {
        try {
          return tasks.firstWhere((task) => task.id == taskId);
        } catch (_) {
          return null;
        }
      },
      loading: () => null,
      error: (_, _) => null,
    );
  },
);

final tasksByProjectProvider = Provider.family<List<TaskModel>, String>(
  (ref, projectId) {
    final tasksState = ref.watch(taskControllerProvider);

    return tasksState.when(
      data: (tasks) {
        return tasks.where((task) => task.projectId == projectId).toList();
      },
      loading: () => [],
      error: (_, _) => [],
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

  Future<void> updateTask(TaskModel task) async {
    final currentTasks = state.value ?? [];
    final updatedTasks =
        currentTasks.map((t) => t.id == task.id ? task : t).toList();

    state = AsyncValue.data(updatedTasks);

    await ref.read(taskRepositoryProvider).updateTask(task);
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

  Future<void> deleteTask(String id) async {
    final currentTasks = state.value ?? [];
    final updatedTasks = currentTasks.where((task) => task.id != id).toList();

    state = AsyncValue.data(updatedTasks);

    await ref.read(taskRepositoryProvider).deleteTask(id);
  }

  Future<void> resetTasks() async {
    final repository = ref.read(taskRepositoryProvider);
    await repository.resetTasks();
    state = AsyncValue.data(await repository.getTasks());
  }
}