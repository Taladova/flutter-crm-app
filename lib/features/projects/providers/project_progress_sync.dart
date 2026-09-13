import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client_action_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/timeline_event_model.dart';
import '../../actions/providers/project_action_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../../timeline/providers/timeline_providers.dart';
import 'project_providers.dart';

/// Recomputes `project.progress` / `project.status` from every structure
/// that contributes work to a project — timeline steps, client actions, and
/// tasks — and persists the result via `ProjectController.updateProject()`.
///
/// This is the single place that triggers the recalculation. Call it after
/// any timeline/action/task mutation that could change what's completed;
/// never compute progress a second way. `updateProject()` already updates
/// the shared `projectControllerProvider` state (so the header and the
/// fiche client refresh immediately) and syncs the client portal.
Future<void> syncProjectProgress(
  Ref ref,
  String projectId, {
  List<ClientActionModel>? actions,
  List<TaskModel>? tasks,
  List<TimelineEventModel>? events,
}) async {
  if (projectId.isEmpty) return;

  final project = ref.read(projectByIdProvider(projectId));
  if (project == null) return;

  final projectEvents =
      (events ??
              ref.read(timelineControllerProvider).value ??
              const <TimelineEventModel>[])
          .where((event) => event.projectId == projectId)
          .toList();
  final projectActions =
      (actions ??
              ref.read(projectActionControllerProvider).value ??
              const <ClientActionModel>[])
          .where((action) => action.projectId == projectId)
          .toList();
  final projectTasks =
      (tasks ?? ref.read(taskControllerProvider).value ?? const <TaskModel>[])
          .where((task) => task.projectId == projectId)
          .toList();

  final updatedProject = ref
      .read(projectTimelineProgressServiceProvider)
      .applyToProject(
        project: project,
        events: projectEvents,
        actions: projectActions,
        tasks: projectTasks,
      );

  if (updatedProject.progress == project.progress &&
      updatedProject.status == project.status &&
      updatedProject.currentStep == project.currentStep &&
      updatedProject.nextStep == project.nextStep) {
    return;
  }

  await ref
      .read(projectControllerProvider.notifier)
      .updateProject(updatedProject);
}
