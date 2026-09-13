import 'package:clientflow_pro/data/models/client_account_model.dart';
import 'package:clientflow_pro/data/models/client_action_model.dart';
import 'package:clientflow_pro/data/models/client_document_model.dart';
import 'package:clientflow_pro/data/models/client_invitation_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Client portal models', () {
    test('ClientInvitationModel preserves invitation access data', () {
      final invitation = ClientInvitationModel.fromJson({
        'token': 'DG72K9',
        'professionalId': 'pro_1',
        'clientId': 'client_1',
        'clientName': 'David',
        'clientEmail': 'david@example.com',
        'projectIds': ['project_1'],
        'status': 'active',
      });

      expect(invitation.isActive, isTrue);
      expect(invitation.projectIds, ['project_1']);
      expect(invitation.toJson()['clientEmail'], 'david@example.com');
    });

    test('ClientAccountModel carries role and allowed projects', () {
      final account = ClientAccountModel.fromJson({
        'uid': 'client_uid',
        'clientId': 'client_1',
        'professionalId': 'pro_1',
        'email': 'client@example.com',
        'displayName': 'Client',
        'role': 'client',
        'projectIds': ['project_1', 'project_2'],
      });

      expect(account.role, 'client');
      expect(account.projectIds.length, 2);
      expect(account.toJson()['professionalId'], 'pro_1');
    });

    test('ClientDocumentModel keeps file metadata only', () {
      final document = ClientDocumentModel.fromJson({
        'id': 'doc_1',
        'name': 'Logo',
        'type': 'image',
        'clientId': 'client_1',
        'uploadedBy': 'client',
        'url': 'https://example.com/logo.png',
        'storagePath': 'users/pro/clients/client_1/documents/doc_1/logo.png',
        'status': 'Reçu',
        'comment': 'Version HD',
      });

      expect(document.status, 'Reçu');
      expect(document.storagePath, contains('documents/doc_1'));
      expect(document.toJson()['url'], isNotEmpty);
    });

    test('ClientActionModel defaults to visible pending actions', () {
      final action = ClientActionModel.fromJson({
        'id': 'action_1',
        'professionalUid': 'pro_1',
        'projectId': 'project_1',
        'clientId': 'client_1',
        'title': 'Valider la maquette',
        'description': 'Merci de confirmer ou demander une modification.',
        'assignedTo': 'client',
        'type': 'validation',
        'priority': 'high',
        'status': 'pending',
      });

      expect(action.visibleToClient, isTrue);
      expect(action.status, 'pending');
      expect(action.assignedTo, 'client');
      expect(action.priority, 'high');
      expect(action.professionalUid, 'pro_1');
      expect(action.toJson()['type'], 'validation');
    });

    test('ClientActionModel keeps backward-compatible defaults', () {
      final action = ClientActionModel.fromJson({
        'id': 'legacy_action',
        'projectId': 'project_1',
        'clientId': 'client_1',
        'title': 'Répondre au client',
        'description': '',
        'type': 'information',
        'status': 'pending',
      });

      expect(action.professionalUid, isEmpty);
      expect(action.assignedTo, 'professional');
      expect(action.priority, 'medium');
      expect(action.visibleToClient, isTrue);
      expect(action.isPending, isTrue);
    });

    test('ClientActionModel copyWith can complete an action', () {
      final action = ClientActionModel.fromJson({
        'id': 'action_2',
        'professionalUid': 'pro_1',
        'projectId': 'project_1',
        'clientId': 'client_1',
        'title': 'Envoyer le logo HD',
        'description': '',
        'assignedTo': 'professional',
        'type': 'document',
        'priority': 'medium',
        'status': 'pending',
      });
      final completedAt = DateTime(2026, 8, 26);
      final completed = action.copyWith(
        status: 'completed',
        completedAt: completedAt,
      );

      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, completedAt);
      expect(completed.toJson()['status'], 'completed');
    });
  });
}
