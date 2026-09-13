import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/task_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/repositories/task_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../client_portal/providers/client_portal_providers.dart';
import '../../projects/providers/project_progress_sync.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(firestoreService: ref.watch(firestoreServiceProvider));
});

final taskControllerProvider =
    AsyncNotifierProvider<TaskController, List<TaskModel>>(TaskController.new);

final taskByIdProvider = Provider.family<TaskModel?, String>((ref, taskId) {
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
});

final tasksByProjectProvider = Provider.family<List<TaskModel>, String>((
  ref,
  projectId,
) {
  final tasksState = ref.watch(taskControllerProvider);

  return tasksState.when(
    data: (tasks) {
      return tasks.where((task) => task.projectId == projectId).toList();
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

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
    await _syncTaskToClientPortal(task);
    await syncProjectProgress(ref, task.projectId, tasks: updatedTasks);
  }

  Future<void> updateTask(TaskModel task) async {
    final currentTasks = state.value ?? [];
    final updatedTasks = currentTasks
        .map((t) => t.id == task.id ? task : t)
        .toList();

    state = AsyncValue.data(updatedTasks);

    await ref.read(taskRepositoryProvider).updateTask(task);
    await _syncTaskToClientPortal(task);
    await syncProjectProgress(ref, task.projectId, tasks: updatedTasks);
  }

  Future<void> toggleTaskStatus(TaskModel selectedTask) async {
    final currentTasks = state.value ?? [];

    final updatedTasks = currentTasks.map((task) {
      if (task.id == selectedTask.id) {
        final isDone = task.status == 'Terminé';

        return task.copyWith(status: isDone ? 'À faire' : 'Terminé');
      }

      return task;
    }).toList();

    state = AsyncValue.data(updatedTasks);

    final updatedTask = updatedTasks.firstWhere(
      (task) => task.id == selectedTask.id,
    );

    await ref.read(taskRepositoryProvider).updateTask(updatedTask);
    await _syncTaskToClientPortal(updatedTask);
    await syncProjectProgress(ref, updatedTask.projectId, tasks: updatedTasks);
  }

  Future<void> deleteTask(String id) async {
    final currentTasks = state.value ?? [];
    TaskModel? deletedTask;
    for (final task in currentTasks) {
      if (task.id == id) {
        deletedTask = task;
        break;
      }
    }
    final updatedTasks = currentTasks.where((task) => task.id != id).toList();

    state = AsyncValue.data(updatedTasks);

    await ref.read(taskRepositoryProvider).deleteTask(id);
    if (deletedTask != null) {
      await _deleteTaskFromClientPortal(deletedTask);
      await syncProjectProgress(
        ref,
        deletedTask.projectId,
        tasks: updatedTasks,
      );
    }
  }

  Future<void> clearTasks() async {
    final repository = ref.read(taskRepositoryProvider);
    await repository.clearTasks();
    state = const AsyncValue.data([]);
  }

  Future<void> _syncTaskToClientPortal(TaskModel task) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null || task.projectId.isEmpty) return;

    await ref
        .read(clientPortalServiceProvider)
        .syncTaskForClientAccounts(professionalId: uid, task: task);
  }

  Future<void> _deleteTaskFromClientPortal(TaskModel task) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null || task.projectId.isEmpty) return;

    await ref
        .read(clientPortalServiceProvider)
        .deleteTaskForClientAccounts(professionalId: uid, task: task);
  }
}
