import 'client_action_model.dart';
import 'document_request_model.dart';
import 'project_model.dart';
import 'task_model.dart';

class MorningBriefModel {
  const MorningBriefModel({
    required this.needsAttentionProjects,
    required this.overdueActions,
    required this.pendingClientActions,
    required this.receivedDocuments,
    required this.todayTasks,
    required this.waitingValidations,
  });

  final List<ProjectModel> needsAttentionProjects;
  final List<ClientActionModel> overdueActions;
  final List<ClientActionModel> pendingClientActions;
  final List<DocumentRequestModel> receivedDocuments;
  final List<TaskModel> todayTasks;
  final List<ClientActionModel> waitingValidations;

  int get needsAttentionProjectsCount => needsAttentionProjects.length;
  int get overdueActionsCount => overdueActions.length;
  int get pendingClientActionsCount => pendingClientActions.length;
  int get receivedDocumentsCount => receivedDocuments.length;
  int get todayTasksCount => todayTasks.length;
  int get waitingValidationsCount => waitingValidations.length;

  bool get hasAttentionItems {
    return needsAttentionProjects.isNotEmpty ||
        overdueActions.isNotEmpty ||
        pendingClientActions.isNotEmpty ||
        receivedDocuments.isNotEmpty ||
        todayTasks.isNotEmpty ||
        waitingValidations.isNotEmpty;
  }
}
