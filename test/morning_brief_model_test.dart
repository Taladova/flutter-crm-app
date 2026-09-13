import 'package:clientflow_pro/data/models/client_action_model.dart';
import 'package:clientflow_pro/data/models/document_request_model.dart';
import 'package:clientflow_pro/data/models/morning_brief_model.dart';
import 'package:clientflow_pro/data/models/project_model.dart';
import 'package:clientflow_pro/data/models/task_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MorningBriefModel exposes dashboard counters', () {
    final brief = MorningBriefModel(
      needsAttentionProjects: const [
        ProjectModel(
          id: 'project_1',
          title: 'Site vitrine',
          clientName: 'Client',
          type: 'Site internet',
          status: 'En cours',
          budget: '1200',
          deadline: '30/08/2026',
          progress: 0.4,
        ),
      ],
      overdueActions: const [
        ClientActionModel(
          id: 'action_1',
          professionalUid: 'pro_1',
          projectId: 'project_1',
          clientId: 'client_1',
          title: 'Relancer le client',
          description: '',
          assignedTo: 'professional',
          type: 'task',
          priority: 'high',
          status: 'pending',
        ),
      ],
      pendingClientActions: const [],
      receivedDocuments: const [
        DocumentRequestModel(
          id: 'doc_1',
          professionalUid: 'pro_1',
          clientId: 'client_1',
          projectId: 'project_1',
          title: 'Logo',
          description: '',
          status: 'received',
          required: true,
        ),
      ],
      todayTasks: const [
        TaskModel(
          id: 'task_1',
          title: 'Préparer la maquette',
          projectName: 'Site vitrine',
          projectId: 'project_1',
          status: 'À faire',
          priority: 'Moyenne',
          deadline: '27/08/2026',
        ),
      ],
      waitingValidations: const [],
    );

    expect(brief.needsAttentionProjectsCount, 1);
    expect(brief.overdueActionsCount, 1);
    expect(brief.receivedDocumentsCount, 1);
    expect(brief.todayTasksCount, 1);
    expect(brief.hasAttentionItems, isTrue);
  });
}
