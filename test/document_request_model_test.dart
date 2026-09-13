import 'package:clientflow_pro/data/models/document_request_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentRequestModel', () {
    test('preserves document request data', () {
      final dueDate = DateTime(2026, 9, 4);
      final request = DocumentRequestModel.fromJson({
        'id': 'request_1',
        'professionalUid': 'pro_1',
        'clientId': 'client_1',
        'projectId': 'project_1',
        'title': 'Logo HD',
        'description': 'Logo en PNG transparent',
        'status': 'requested',
        'required': true,
        'dueDate': dueDate,
        'uploadedDocumentId': null,
      });

      expect(request.id, 'request_1');
      expect(request.title, 'Logo HD');
      expect(request.isRequested, isTrue);
      expect(request.required, isTrue);
      expect(request.dueDate, dueDate);
    });

    test('calculates document preparation progress from required requests', () {
      final summary = DocumentPreparationSummary.fromRequests([
        _request(id: 'logo', status: 'validated'),
        _request(id: 'photos', status: 'received'),
        _request(id: 'legal', status: 'requested'),
        _request(id: 'bonus', status: 'requested', required: false),
      ]);

      expect(summary.requiredCount, 3);
      expect(summary.receivedCount, 2);
      expect(summary.missingCount, 1);
      expect(summary.progress, closeTo(2 / 3, 0.001));
    });
  });
}

DocumentRequestModel _request({
  required String id,
  required String status,
  bool required = true,
}) {
  return DocumentRequestModel(
    id: id,
    professionalUid: 'pro_1',
    clientId: 'client_1',
    projectId: 'project_1',
    title: id,
    description: '',
    status: status,
    required: required,
  );
}
