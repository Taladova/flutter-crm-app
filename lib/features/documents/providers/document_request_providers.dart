import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client_action_model.dart';
import '../../../data/models/document_request_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/repositories/document_request_repository.dart';
import '../../actions/providers/project_action_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../client_portal/providers/client_portal_providers.dart';

final documentRequestRepositoryProvider = Provider<DocumentRequestRepository>((
  ref,
) {
  return DocumentRequestRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});

final documentRequestControllerProvider =
    AsyncNotifierProvider<
      DocumentRequestController,
      List<DocumentRequestModel>
    >(DocumentRequestController.new);

final documentRequestsStreamProvider =
    StreamProvider<List<DocumentRequestModel>>((ref) {
      return ref.watch(documentRequestRepositoryProvider).requestsStream();
    });

final documentRequestsByClientProvider =
    Provider.family<List<DocumentRequestModel>, String>((ref, clientId) {
      final streamedRequests = ref.watch(documentRequestsStreamProvider).value;
      final fallbackRequests = ref
          .watch(documentRequestControllerProvider)
          .value;
      return (streamedRequests ??
              fallbackRequests ??
              const <DocumentRequestModel>[])
          .where((request) => request.clientId == clientId)
          .toList();
    });

class DocumentRequestController
    extends AsyncNotifier<List<DocumentRequestModel>> {
  @override
  Future<List<DocumentRequestModel>> build() {
    return ref.watch(documentRequestRepositoryProvider).getRequests();
  }

  Future<void> addRequest(DocumentRequestModel request) async {
    final now = DateTime.now();
    final professionalUid = request.professionalUid.isNotEmpty
        ? request.professionalUid
        : ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    final prepared = request.copyWith(
      professionalUid: professionalUid,
      createdAt: request.createdAt ?? now,
      updatedAt: now,
    );

    final current = state.value ?? const <DocumentRequestModel>[];
    state = AsyncValue.data([prepared, ...current]);

    await ref.read(documentRequestRepositoryProvider).setRequest(prepared);
    await ref
        .read(clientPortalServiceProvider)
        .syncDocumentRequestForClientAccounts(request: prepared);

    await ref
        .read(projectActionControllerProvider.notifier)
        .addAction(
          ClientActionModel(
            id: prepared.id,
            professionalUid: prepared.professionalUid,
            clientId: prepared.clientId,
            projectId: prepared.projectId,
            title: prepared.title,
            description: prepared.description,
            assignedTo: 'client',
            type: 'document',
            priority: prepared.required ? 'high' : 'medium',
            status: 'pending',
            visibleToClient: true,
            dueDate: prepared.dueDate,
            createdAt: prepared.createdAt,
            updatedAt: prepared.updatedAt,
          ),
        );
  }

  Future<void> updateRequest(DocumentRequestModel request) async {
    final prepared = request.copyWith(updatedAt: DateTime.now());
    final current = state.value ?? const <DocumentRequestModel>[];
    state = AsyncValue.data(
      current.map((item) => item.id == prepared.id ? prepared : item).toList(),
    );

    await ref.read(documentRequestRepositoryProvider).setRequest(prepared);
    await ref
        .read(clientPortalServiceProvider)
        .updateDocumentRequestStatusForClient(request: prepared);
  }

  Future<void> deleteRequest(DocumentRequestModel request) async {
    final current = state.value ?? const <DocumentRequestModel>[];
    state = AsyncValue.data(
      current.where((item) => item.id != request.id).toList(),
    );

    await ref.read(documentRequestRepositoryProvider).deleteRequest(request.id);
    await ref
        .read(clientPortalServiceProvider)
        .deleteDocumentRequestForClientAccounts(request: request);
    await ref
        .read(projectActionControllerProvider.notifier)
        .deleteAction(
          ClientActionModel(
            id: request.id,
            professionalUid: request.professionalUid,
            clientId: request.clientId,
            projectId: request.projectId,
            title: request.title,
            description: request.description,
            assignedTo: 'client',
            type: 'document',
            priority: 'medium',
            status: 'pending',
          ),
        );
  }
}
