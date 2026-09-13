import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/project_model.dart';
import '../models/project_template_model.dart';
import '../models/timeline_event_model.dart';
import 'project_timeline_progress_service.dart';

class ProjectTemplateService {
  const ProjectTemplateService({required this.firestore, required this.auth});

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  Future<void> createProjectFromTemplate({
    required ProjectModel project,
    required ProjectTemplateModel template,
    required String clientId,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Utilisateur non connecté');

    final batch = firestore.batch();
    final userRef = firestore.collection('users').doc(uid);
    final now = DateTime.now();
    final clientAccounts = await _matchingClientAccounts(
      professionalUid: uid,
      clientId: clientId,
      clientName: project.clientName,
    );
    final timelineEvents = <TimelineEventModel>[
      for (var index = 0; index < template.timeline.length; index++)
        TimelineEventModel(
          id: '${project.id}_timeline_$index',
          projectId: project.id,
          professionalUid: uid,
          title: template.timeline[index].title,
          description: template.timeline[index].description,
          status: template.timeline[index].status,
          date: _dateFromOffset(now, template.timeline[index].daysOffset),
          order: (index + 1) * 1000,
          visibleToClient: template.timeline[index].visibleToClient,
        ),
    ];
    final preparedProject = const ProjectTimelineProgressService()
        .applyToProject(project: project, events: timelineEvents);

    batch.set(
      userRef.collection('projects').doc(project.id),
      preparedProject.toJson(),
    );

    for (final account in clientAccounts) {
      batch.set(account.reference, {
        'projectIds': FieldValue.arrayUnion([project.id]),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(account.reference.collection('projects').doc(project.id), {
        'projectId': project.id,
        'professionalId': uid,
        'clientId': account.data()['clientId'] ?? clientId,
        'title': preparedProject.title,
        'clientName': preparedProject.clientName,
        'type': preparedProject.type,
        'status': preparedProject.status,
        'budget': preparedProject.budget,
        'deadline': preparedProject.deadline,
        'progress': preparedProject.progress,
        'currentStep': preparedProject.currentStep,
        'nextStep': preparedProject.nextStep,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    for (final event in timelineEvents) {
      final data = {
        ...event.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.set(userRef.collection('timeline').doc(event.id), data);

      if (event.visibleToClient) {
        for (final account in clientAccounts) {
          batch.set(
            account.reference.collection('timeline').doc(event.id),
            data,
            SetOptions(merge: true),
          );
        }
      }
    }

    for (var index = 0; index < template.tasks.length; index++) {
      final task = template.tasks[index];
      final id = '${project.id}_task_$index';
      batch.set(userRef.collection('tasks').doc(id), {
        'id': id,
        'title': task.title,
        'projectName': project.title,
        'projectId': project.id,
        'status': 'À faire',
        'priority': task.priority,
        'deadline': _deadlineLabel(now, task.daysOffset),
        'visibleToClient': true,
        'internal': false,
        'private': false,
        'assignedTo': 'professional',
      });
    }

    for (var index = 0; index < template.clientActions.length; index++) {
      final action = template.clientActions[index];
      final id = '${project.id}_action_$index';
      final data = {
        'id': id,
        'professionalUid': uid,
        'clientId': clientId,
        'projectId': project.id,
        'title': action.title,
        'description': action.description,
        'assignedTo': 'client',
        'type': action.type,
        'priority': action.priority,
        'status': 'pending',
        'visibleToClient': action.visibleToClient,
        'dueDate': _dateFromOffset(now, action.daysOffset),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'completedAt': null,
      };
      batch.set(userRef.collection('project_actions').doc(id), data);

      if (action.visibleToClient) {
        for (final account in clientAccounts) {
          batch.set(account.reference.collection('actions').doc(id), {
            ...data,
            'clientId': account.data()['clientId'] ?? clientId,
          }, SetOptions(merge: true));
        }
      }
    }

    for (var index = 0; index < template.documentRequests.length; index++) {
      final request = template.documentRequests[index];
      final id = '${project.id}_document_request_$index';
      final dueDate = _dateFromOffset(now, request.daysOffset);
      final requestData = {
        'id': id,
        'professionalUid': uid,
        'clientId': clientId,
        'projectId': project.id,
        'title': request.title,
        'description': request.description,
        'status': 'requested',
        'required': request.required,
        'dueDate': dueDate,
        'uploadedDocumentId': null,
        'rejectionComment': '',
        'clientUid': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final actionData = {
        'id': id,
        'professionalUid': uid,
        'clientId': clientId,
        'projectId': project.id,
        'title': request.title,
        'description': request.description,
        'assignedTo': 'client',
        'type': 'document',
        'priority': request.required ? 'high' : 'medium',
        'status': 'pending',
        'visibleToClient': true,
        'dueDate': dueDate,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'completedAt': null,
      };
      batch.set(userRef.collection('document_requests').doc(id), requestData);
      batch.set(userRef.collection('project_actions').doc(id), actionData);

      for (final account in clientAccounts) {
        batch.set(account.reference.collection('document_requests').doc(id), {
          ...requestData,
          'clientId': account.data()['clientId'] ?? clientId,
          'clientUid': account.id,
        }, SetOptions(merge: true));
        batch.set(account.reference.collection('actions').doc(id), {
          ...actionData,
          'clientId': account.data()['clientId'] ?? clientId,
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
  }

  DateTime? _dateFromOffset(DateTime now, int? offset) {
    if (offset == null) return null;
    return DateTime(now.year, now.month, now.day).add(Duration(days: offset));
  }

  String _deadlineLabel(DateTime now, int? offset) {
    final date = _dateFromOffset(now, offset);
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _matchingClientAccounts({
    required String professionalUid,
    required String clientId,
    required String clientName,
  }) async {
    final snapshot = await firestore
        .collection('client_accounts')
        .where('professionalId', isEqualTo: professionalUid)
        .get();
    final normalizedClientId = clientId.trim().toLowerCase();
    final normalizedClientName = clientName.trim().toLowerCase();

    return snapshot.docs.where((doc) {
      final data = doc.data();
      final accountClientId = '${data['clientId'] ?? ''}'.trim().toLowerCase();
      final accountName = '${data['displayName'] ?? ''}'.trim().toLowerCase();

      return (normalizedClientId.isNotEmpty &&
              accountClientId == normalizedClientId) ||
          (normalizedClientName.isNotEmpty &&
              (accountName == normalizedClientName ||
                  accountClientId == normalizedClientName));
    }).toList();
  }
}
