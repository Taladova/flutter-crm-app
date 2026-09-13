import 'package:clientflow_pro/data/models/client_action_model.dart';
import 'package:clientflow_pro/data/services/project_waiting_status_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectWaitingStatusService', () {
    const service = ProjectWaitingStatusService();
    final now = DateTime(2026, 8, 26);

    test('returns ready when no important action is pending', () {
      final summary = service.evaluate(
        now: now,
        actions: [
          _action(
            id: 'low_later',
            assignedTo: 'client',
            priority: 'low',
            dueDate: DateTime(2026, 9, 20),
          ),
        ],
      );

      expect(summary.state, ProjectWaitingState.ready);
      expect(summary.clientPendingActions, 1);
      expect(summary.primaryAction, isNull);
    });

    test('detects work waiting for the professional', () {
      final summary = service.evaluate(
        now: now,
        actions: [
          _action(
            id: 'send_mockup',
            assignedTo: 'professional',
            priority: 'medium',
          ),
        ],
      );

      expect(summary.state, ProjectWaitingState.waitingProfessional);
      expect(summary.professionalPendingActions, 1);
      expect(summary.primaryAction?.title, 'Action send_mockup');
    });

    test('detects work waiting for the client', () {
      final summary = service.evaluate(
        now: now,
        actions: [
          _action(id: 'validate_logo', assignedTo: 'client', priority: 'high'),
        ],
      );

      expect(summary.state, ProjectWaitingState.waitingClient);
      expect(summary.clientPendingActions, 1);
      expect(summary.primaryAction?.assignedTo, 'client');
    });

    test('marks project blocked when important action is overdue for days', () {
      final summary = service.evaluate(
        now: now,
        actions: [
          _action(
            id: 'homepage_validation',
            assignedTo: 'client',
            priority: 'medium',
            dueDate: DateTime(2026, 8, 21),
          ),
        ],
      );

      expect(summary.state, ProjectWaitingState.blocked);
      expect(summary.blockedDays, 5);
      expect(summary.overdueClientActions, 1);
    });
  });
}

ClientActionModel _action({
  required String id,
  required String assignedTo,
  required String priority,
  DateTime? dueDate,
}) {
  return ClientActionModel(
    id: id,
    professionalUid: 'pro_1',
    projectId: 'project_1',
    clientId: 'client_1',
    title: 'Action $id',
    description: '',
    assignedTo: assignedTo,
    type: 'task',
    priority: priority,
    status: 'pending',
    dueDate: dueDate,
    visibleToClient: true,
  );
}
