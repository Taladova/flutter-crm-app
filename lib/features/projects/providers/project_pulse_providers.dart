import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client_action_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/project_pulse_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/services/project_pulse_service.dart';
import '../../actions/providers/project_action_providers.dart';
import '../../tasks/providers/task_providers.dart';
import 'project_providers.dart';

final projectPulseServiceProvider = Provider<ProjectPulseService>((ref) {
  return const ProjectPulseService();
});

final projectPulseProvider =
    Provider.family<AsyncValue<ProjectPulseModel>, String>((ref, projectId) {
      final projectsState = ref.watch(projectControllerProvider);
      final tasksState = ref.watch(taskControllerProvider);
      final actionsState = ref.watch(projectActionControllerProvider);

      if (projectsState.isLoading ||
          tasksState.isLoading ||
          actionsState.isLoading) {
        return const AsyncValue.loading();
      }

      if (projectsState.hasError) {
        return AsyncValue.error(
          projectsState.error!,
          projectsState.stackTrace ?? StackTrace.current,
        );
      }
      if (tasksState.hasError) {
        return AsyncValue.error(
          tasksState.error!,
          tasksState.stackTrace ?? StackTrace.current,
        );
      }
      if (actionsState.hasError) {
        return AsyncValue.error(
          actionsState.error!,
          actionsState.stackTrace ?? StackTrace.current,
        );
      }

      final projects = projectsState.value ?? const <ProjectModel>[];
      ProjectModel? project;
      for (final item in projects) {
        if (item.id == projectId) {
          project = item;
          break;
        }
      }
      if (project == null) {
        return AsyncValue.error(
          StateError('Projet introuvable'),
          StackTrace.current,
        );
      }

      final tasks = (tasksState.value ?? const <TaskModel>[])
          .where((task) => task.projectId == projectId)
          .toList();
      final actions = (actionsState.value ?? const <ClientActionModel>[])
          .where((action) => action.projectId == projectId)
          .toList();

      return AsyncValue.data(
        ref
            .watch(projectPulseServiceProvider)
            .evaluate(project: project, actions: actions, tasks: tasks),
      );
    });

final projectPulseDashboardProvider =
    Provider<AsyncValue<ProjectPulseDashboardSummary>>((ref) {
      final projectsState = ref.watch(projectControllerProvider);
      final tasksState = ref.watch(taskControllerProvider);
      final actionsState = ref.watch(projectActionControllerProvider);

      if (projectsState.isLoading ||
          tasksState.isLoading ||
          actionsState.isLoading) {
        return const AsyncValue.loading();
      }

      if (projectsState.hasError) {
        return AsyncValue.error(
          projectsState.error!,
          projectsState.stackTrace ?? StackTrace.current,
        );
      }
      if (tasksState.hasError) {
        return AsyncValue.error(
          tasksState.error!,
          tasksState.stackTrace ?? StackTrace.current,
        );
      }
      if (actionsState.hasError) {
        return AsyncValue.error(
          actionsState.error!,
          actionsState.stackTrace ?? StackTrace.current,
        );
      }

      final projects = projectsState.value ?? const <ProjectModel>[];
      final tasks = tasksState.value ?? const <TaskModel>[];
      final actions = actionsState.value ?? const <ClientActionModel>[];
      final service = ref.watch(projectPulseServiceProvider);

      final pulses = projects.map((project) {
        return service.evaluate(
          project: project,
          tasks: tasks.where((task) => task.projectId == project.id).toList(),
          actions: actions
              .where((action) => action.projectId == project.id)
              .toList(),
        );
      }).toList();

      return AsyncValue.data(service.summarize(pulses));
    });
