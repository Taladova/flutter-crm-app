import '../models/client_action_model.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/timeline_event_model.dart';

class ProjectTimelineProgressResult {
  const ProjectTimelineProgressResult({
    required this.progress,
    required this.status,
    required this.currentStep,
    required this.nextStep,
  });

  final double progress;
  final String status;
  final String currentStep;
  final String nextStep;
}

/// Single source of truth for a project's progress and status.
///
/// Every structure that contributes work to a project — timeline steps,
/// client actions, and tasks — is combined into one completed/total count.
/// Never compute progress a second way anywhere else: call
/// `applyToProject`/`calculate` and persist the result on `project.progress`
/// / `project.status`; every screen reads those two fields.
class ProjectTimelineProgressService {
  const ProjectTimelineProgressService();

  ProjectTimelineProgressResult calculate({
    List<TimelineEventModel> events = const [],
    List<ClientActionModel> actions = const [],
    List<TaskModel> tasks = const [],
  }) {
    final sortedEvents = [...events]
      ..sort((a, b) => a.order.compareTo(b.order));

    final completedEvents = sortedEvents
        .where((event) => event.isCompleted)
        .length;
    final completedActions = actions
        .where((action) => action.isCompleted)
        .length;
    final completedTasks = tasks.where(_isTaskDone).length;

    final totalItems = sortedEvents.length + actions.length + tasks.length;
    final completedItems = completedEvents + completedActions + completedTasks;

    final progress = totalItems == 0
        ? 0.0
        : (completedItems / totalItems).clamp(0.0, 1.0);

    // Single automatic status rule, derived only from progress:
    // 0% = Planifié, 0% < x < 100% = En cours, 100% = Terminé.
    final status = progress <= 0
        ? 'Planifié'
        : progress >= 1
        ? 'Terminé'
        : 'En cours';

    final currentStep = sortedEvents.isEmpty ? '' : _currentStep(sortedEvents);
    final nextStep = sortedEvents.isEmpty ? '' : _nextStep(sortedEvents);

    return ProjectTimelineProgressResult(
      progress: progress,
      status: status,
      currentStep: currentStep,
      nextStep: nextStep,
    );
  }

  ProjectModel applyToProject({
    required ProjectModel project,
    List<TimelineEventModel> events = const [],
    List<ClientActionModel> actions = const [],
    List<TaskModel> tasks = const [],
  }) {
    final result = calculate(events: events, actions: actions, tasks: tasks);
    return project.copyWith(
      progress: result.progress,
      status: result.status,
      currentStep: result.currentStep,
      nextStep: result.nextStep,
    );
  }

  bool _isTaskDone(TaskModel task) {
    final status = task.status.trim().toLowerCase();
    return status == 'terminé' || status == 'termine';
  }

  String _currentStep(List<TimelineEventModel> events) {
    for (final event in events) {
      if (event.isCurrent) return event.title;
    }

    for (final event in events) {
      if (!event.isCompleted) return event.title;
    }

    return events.last.title;
  }

  String _nextStep(List<TimelineEventModel> events) {
    final currentIndex = events.indexWhere((event) => event.isCurrent);
    if (currentIndex >= 0) {
      for (final event in events.skip(currentIndex + 1)) {
        if (!event.isCompleted) return event.title;
      }
      return '';
    }

    for (final event in events) {
      if (event.isUpcoming) return event.title;
    }

    return '';
  }
}
