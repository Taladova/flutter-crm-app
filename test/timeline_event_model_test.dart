import 'package:clientflow_pro/data/models/timeline_event_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimelineEventModel', () {
    test('preserves project timeline data', () {
      final date = DateTime(2026, 9, 8);
      final event = TimelineEventModel.fromJson({
        'id': 'timeline_1',
        'projectId': 'project_1',
        'professionalUid': 'pro_1',
        'title': 'Mise en ligne',
        'description': 'Publication du site',
        'status': 'upcoming',
        'date': date,
        'order': 3000,
        'visibleToClient': true,
      });

      expect(event.id, 'timeline_1');
      expect(event.projectId, 'project_1');
      expect(event.professionalUid, 'pro_1');
      expect(event.title, 'Mise en ligne');
      expect(event.isUpcoming, isTrue);
      expect(event.date, date);
      expect(event.visibleToClient, isTrue);
    });

    test('copyWith can mark current step', () {
      const event = TimelineEventModel(
        id: 'timeline_1',
        projectId: 'project_1',
        professionalUid: 'pro_1',
        title: 'Développement',
        description: '',
        status: 'upcoming',
        order: 1000,
      );

      final updated = event.copyWith(status: 'current');

      expect(updated.isCurrent, isTrue);
      expect(updated.isUpcoming, isFalse);
    });
  });
}
