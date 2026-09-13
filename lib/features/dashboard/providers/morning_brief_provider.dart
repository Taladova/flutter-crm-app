import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client_action_model.dart';
import '../../../data/models/document_request_model.dart';
import '../../../data/models/morning_brief_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/project_pulse_model.dart';
import '../../../data/models/task_model.dart';
import '../../actions/providers/project_action_providers.dart';
import '../../documents/providers/document_request_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../../projects/providers/project_pulse_providers.dart';
import '../../tasks/providers/task_providers.dart';

final morningBriefProvider = Provider<AsyncValue<MorningBriefModel>>((ref) {
  final projectsState = ref.watch(projectControllerProvider);
  final tasksState = ref.watch(taskControllerProvider);
  final actionsState = ref.watch(projectActionControllerProvider);
  final documentsState = ref.watch(documentRequestControllerProvider);
  final pulseState = ref.watch(projectPulseDashboardProvider);

  if (projectsState.isLoading ||
      tasksState.isLoading ||
      actionsState.isLoading ||
      documentsState.isLoading ||
      pulseState.isLoading) {
    return const AsyncValue.loading();
  }

  for (final state in [
    projectsState,
    tasksState,
    actionsState,
    documentsState,
    pulseState,
  ]) {
    if (state.hasError) {
      return AsyncValue.error(
        state.error!,
        state.stackTrace ?? StackTrace.current,
      );
    }
  }

  final projects = projectsState.value ?? const <ProjectModel>[];
  final tasks = tasksState.value ?? const <TaskModel>[];
  final actions = actionsState.value ?? const <ClientActionModel>[];
  final documents = documentsState.value ?? const <DocumentRequestModel>[];
  final pulseSummary = pulseState.value;
  final today = _today();

  final needsAttentionProjectIds =
      pulseSummary
          ?.byStatus(ProjectPulseStatus.needsAttention)
          .map((pulse) => pulse.projectId)
          .toSet() ??
      const <String>{};

  final needsAttentionProjects = projects
      .where((project) => needsAttentionProjectIds.contains(project.id))
      .toList();

  final pendingActions = actions
      .where((action) => action.status == 'pending')
      .toList();

  final overdueActions = pendingActions
      .where((action) => _isBeforeToday(action.dueDate, today))
      .toList();

  final pendingClientActions = pendingActions
      .where((action) => action.assignedTo == 'client')
      .toList();

  final waitingValidations = pendingClientActions
      .where((action) => action.type == 'validation')
      .toList();

  final receivedDocuments = documents
      .where(
        (document) =>
            document.isReceived && _isToday(document.updatedAt, today),
      )
      .toList();

  final todayTasks = tasks
      .where((task) => task.status != 'Terminé')
      .where((task) => _isTaskDueToday(task.deadline, today))
      .toList();

  overdueActions.sort(_compareActionsByUrgency);
  pendingClientActions.sort(_compareActionsByUrgency);
  waitingValidations.sort(_compareActionsByUrgency);
  todayTasks.sort((a, b) => a.title.compareTo(b.title));

  return AsyncValue.data(
    MorningBriefModel(
      needsAttentionProjects: needsAttentionProjects,
      overdueActions: overdueActions,
      pendingClientActions: pendingClientActions,
      receivedDocuments: receivedDocuments,
      todayTasks: todayTasks,
      waitingValidations: waitingValidations,
    ),
  );
});

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

bool _isBeforeToday(DateTime? date, DateTime today) {
  if (date == null) return false;
  return DateTime(date.year, date.month, date.day).isBefore(today);
}

bool _isToday(DateTime? date, DateTime today) {
  if (date == null) return false;
  return DateTime(date.year, date.month, date.day) == today;
}

bool _isTaskDueToday(String deadline, DateTime today) {
  final normalized = deadline.trim().toLowerCase();
  if (normalized == 'aujourd’hui' || normalized == "aujourd'hui") return true;

  final parts = normalized.split('/');
  if (parts.length != 3) return false;

  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return false;

  return DateTime(year, month, day) == today;
}

int _compareActionsByUrgency(ClientActionModel a, ClientActionModel b) {
  final overdueCompare = _overdueRank(b).compareTo(_overdueRank(a));
  if (overdueCompare != 0) return overdueCompare;

  final priorityCompare = _priorityRank(
    b.priority,
  ).compareTo(_priorityRank(a.priority));
  if (priorityCompare != 0) return priorityCompare;

  final aDate = a.dueDate ?? DateTime(9999);
  final bDate = b.dueDate ?? DateTime(9999);
  return aDate.compareTo(bDate);
}

int _overdueRank(ClientActionModel action) {
  return _isBeforeToday(action.dueDate, _today()) ? 1 : 0;
}

int _priorityRank(String priority) {
  switch (priority) {
    case 'high':
      return 3;
    case 'medium':
      return 2;
    case 'low':
      return 1;
    default:
      return 0;
  }
}
