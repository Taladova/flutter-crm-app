import 'package:clientflow_pro/data/models/client_action_model.dart';
import 'package:clientflow_pro/data/models/project_model.dart';
import 'package:clientflow_pro/data/models/project_pulse_model.dart';
import 'package:clientflow_pro/data/models/task_model.dart';
import 'package:clientflow_pro/data/services/project_pulse_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectPulseService', () {
    const service = ProjectPulseService();
    final now = DateTime(2026, 8, 26);

    test('marks project on track when there are no blockers', () {
      final pulse = service.evaluate(
        now: now,
        project: _project(progress: 0.72, deadline: '4 septembre 2026'),
        tasks: [_task(id: 'task_1', deadline: '4 septembre 2026')],
        actions: const [],
      );

      expect(pulse.status, ProjectPulseStatus.onTrack);
      expect(pulse.label, 'Projet en bonne voie');
      expect(pulse.progress, 0.72);
      expect(pulse.nextDeadline, DateTime(2026, 9, 4));
    });

    test(
      'marks project waiting for client when client has important action',
      () {
        final pulse = service.evaluate(
          now: now,
          project: _project(),
          tasks: const [],
          actions: [
            _action(
              id: 'validate_homepage',
              assignedTo: 'client',
              priority: 'high',
              title: 'Validation Homepage',
            ),
          ],
        );

        expect(pulse.status, ProjectPulseStatus.waitingClient);
        expect(pulse.label, 'Attend le client');
        expect(pulse.blockingAction?.title, 'Validation Homepage');
      },
    );

    test('marks project needing attention when tasks are overdue', () {
      final pulse = service.evaluate(
        now: now,
        project: _project(),
        tasks: [_task(id: 'late_task', deadline: '21 août 2026')],
        actions: const [],
      );

      expect(pulse.status, ProjectPulseStatus.needsAttention);
      expect(pulse.reason, '1 tâche en retard');
      expect(pulse.overdueTasks, 1);
    });

    test(
      'marks project needing attention when professional action is blocked',
      () {
        final pulse = service.evaluate(
          now: now,
          project: _project(),
          tasks: const [],
          actions: [
            _action(
              id: 'send_offer',
              assignedTo: 'professional',
              priority: 'medium',
              dueDate: DateTime(2026, 8, 20),
            ),
          ],
        );

        expect(pulse.status, ProjectPulseStatus.needsAttention);
        expect(pulse.daysBlocked, 6);
        expect(pulse.reason, contains('À faire par moi'));
      },
    );

    test('marks project completed from status or progress', () {
      final pulse = service.evaluate(
        now: now,
        project: _project(status: 'Terminé', progress: 1),
        tasks: const [],
        actions: [
          _action(
            id: 'old_client_action',
            assignedTo: 'client',
            priority: 'high',
          ),
        ],
      );

      expect(pulse.status, ProjectPulseStatus.completed);
      expect(pulse.label, 'Projet terminé');
    });
  });
}

ProjectModel _project({
  String status = 'En cours',
  double progress = 0.4,
  String deadline = '30 août 2026',
}) {
  return ProjectModel(
    id: 'project_1',
    title: 'Création site vitrine',
    clientName: 'Client test',
    type: 'Site web',
    status: status,
    budget: '1500€',
    deadline: deadline,
    progress: progress,
  );
}

TaskModel _task({
  required String id,
  required String deadline,
  String status = 'À faire',
}) {
  return TaskModel(
    id: id,
    title: 'Task $id',
    projectName: 'Création site vitrine',
    projectId: 'project_1',
    status: status,
    priority: 'Moyenne',
    deadline: deadline,
  );
}

ClientActionModel _action({
  required String id,
  required String assignedTo,
  required String priority,
  String title = 'Action',
  DateTime? dueDate,
}) {
  return ClientActionModel(
    id: id,
    professionalUid: 'pro_1',
    projectId: 'project_1',
    clientId: 'client_1',
    title: title,
    description: '',
    assignedTo: assignedTo,
    type: 'task',
    priority: priority,
    status: 'pending',
    visibleToClient: true,
    dueDate: dueDate,
  );
}
