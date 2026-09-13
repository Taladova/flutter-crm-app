import 'package:flutter_test/flutter_test.dart';

import 'package:clientflow_pro/data/models/project_model.dart';
import 'package:clientflow_pro/data/models/timeline_event_model.dart';
import 'package:clientflow_pro/data/services/project_timeline_progress_service.dart';

void main() {
  const service = ProjectTimelineProgressService();

  ProjectModel project() => const ProjectModel(
    id: 'project_1',
    title: 'Site vitrine',
    clientName: 'Lida',
    type: 'Site internet',
    status: 'Planifié',
    budget: '2500',
    deadline: '21/09/2026',
    progress: 0,
  );

  TimelineEventModel event({
    required String id,
    required String title,
    required String status,
    required int order,
  }) {
    return TimelineEventModel(
      id: id,
      projectId: 'project_1',
      professionalUid: 'pro_1',
      title: title,
      description: '',
      status: status,
      order: order,
    );
  }

  test('keeps project planned when no timeline step has started', () {
    final updated = service.applyToProject(
      project: project(),
      events: [
        event(id: 'brief', title: 'Brief', status: 'upcoming', order: 1000),
        event(id: 'design', title: 'Maquette', status: 'upcoming', order: 2000),
      ],
    );

    expect(updated.progress, 0);
    expect(updated.status, 'Planifié');
    expect(updated.currentStep, 'Brief');
    expect(updated.nextStep, 'Brief');
  });

  test('marks project in progress from completed and current steps', () {
    final updated = service.applyToProject(
      project: project(),
      events: [
        event(id: 'brief', title: 'Brief', status: 'completed', order: 1000),
        event(id: 'design', title: 'Maquette', status: 'current', order: 2000),
        event(
          id: 'dev',
          title: 'Développement',
          status: 'upcoming',
          order: 3000,
        ),
        event(id: 'test', title: 'Recette', status: 'upcoming', order: 4000),
        event(
          id: 'delivery',
          title: 'Livraison',
          status: 'upcoming',
          order: 5000,
        ),
      ],
    );

    expect(updated.progress, 0.2);
    expect(updated.status, 'En cours');
    expect(updated.currentStep, 'Maquette');
    expect(updated.nextStep, 'Développement');
  });

  test('marks project completed when every timeline step is completed', () {
    final updated = service.applyToProject(
      project: project(),
      events: [
        event(id: 'brief', title: 'Brief', status: 'completed', order: 1000),
        event(
          id: 'delivery',
          title: 'Livraison',
          status: 'completed',
          order: 2000,
        ),
      ],
    );

    expect(updated.progress, 1);
    expect(updated.status, 'Terminé');
    expect(updated.currentStep, 'Livraison');
    expect(updated.nextStep, '');
  });
}
