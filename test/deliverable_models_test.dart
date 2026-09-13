import 'package:clientflow_pro/data/models/deliverable_model.dart';
import 'package:clientflow_pro/data/models/deliverable_version_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliverableModel', () {
    test('preserves validation state', () {
      final deliverable = DeliverableModel.fromJson({
        'id': 'deliverable_1',
        'projectId': 'project_1',
        'clientId': 'client_1',
        'professionalUid': 'pro_1',
        'title': 'Homepage',
        'description': 'Maquette homepage',
        'kind': 'image',
        'currentVersion': 3,
        'status': 'approved',
      });

      expect(deliverable.title, 'Homepage');
      expect(deliverable.currentVersion, 3);
      expect(deliverable.isApproved, isTrue);
      expect(deliverable.toJson()['kind'], 'image');
    });
  });

  group('DeliverableVersionModel', () {
    test('uses storage URL before external URL for preview', () {
      const version = DeliverableVersionModel(
        id: 'version_1',
        deliverableId: 'deliverable_1',
        projectId: 'project_1',
        clientId: 'client_1',
        professionalUid: 'pro_1',
        versionNumber: 1,
        storageUrl: 'https://storage.test/homepage.png',
        externalUrl: 'https://example.com/homepage',
        fileName: 'homepage.png',
        mimeType: 'image/png',
        uploadedBy: 'pro_1',
        status: 'awaitingReview',
      );

      expect(version.previewUrl, 'https://storage.test/homepage.png');
      expect(version.isAwaitingReview, isTrue);
    });

    test('copyWith can request changes with client comment', () {
      const version = DeliverableVersionModel(
        id: 'version_1',
        deliverableId: 'deliverable_1',
        projectId: 'project_1',
        clientId: 'client_1',
        professionalUid: 'pro_1',
        versionNumber: 1,
        fileName: 'homepage.pdf',
        mimeType: 'application/pdf',
        uploadedBy: 'pro_1',
        status: 'awaitingReview',
      );

      final reviewed = version.copyWith(
        status: 'changesRequested',
        clientComment: 'Modifier le hero.',
      );

      expect(reviewed.isChangesRequested, isTrue);
      expect(reviewed.clientComment, 'Modifier le hero.');
    });
  });
}
