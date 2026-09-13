import 'package:clientflow_pro/data/models/deliverable_annotation_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliverableAnnotationModel', () {
    test('keeps normalized coordinates between 0 and 1', () {
      final annotation = DeliverableAnnotationModel.fromJson({
        'id': 'annotation_1',
        'deliverableVersionId': 'deliverable_1_v1',
        'deliverableId': 'deliverable_1',
        'projectId': 'project_1',
        'professionalUid': 'pro_1',
        'authorUid': 'client_1',
        'x': 1.4,
        'y': -0.2,
        'comment': 'Ajouter Instagram ici.',
        'resolved': false,
      });

      expect(annotation.x, 1);
      expect(annotation.y, 0);
      expect(annotation.resolved, isFalse);
      expect(annotation.comment, 'Ajouter Instagram ici.');
    });

    test('copyWith can mark an annotation as resolved', () {
      const annotation = DeliverableAnnotationModel(
        id: 'annotation_1',
        deliverableVersionId: 'deliverable_1_v1',
        deliverableId: 'deliverable_1',
        projectId: 'project_1',
        professionalUid: 'pro_1',
        authorUid: 'client_1',
        x: 0.5,
        y: 0.25,
        comment: 'Le bouton doit être plus visible.',
        resolved: false,
      );

      final resolved = annotation.copyWith(
        resolved: true,
        resolvedAt: DateTime(2026, 8, 26, 14, 34),
      );

      expect(resolved.resolved, isTrue);
      expect(resolved.resolvedAt, isNotNull);
      expect(resolved.x, 0.5);
      expect(resolved.y, 0.25);
    });
  });
}
