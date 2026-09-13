import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client_action_model.dart';
import '../../../data/models/deliverable_annotation_model.dart';
import '../../../data/models/deliverable_model.dart';
import '../../../data/models/deliverable_version_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/repositories/deliverable_repository.dart';
import '../../actions/providers/project_action_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../client_portal/providers/client_portal_providers.dart';

final deliverableRepositoryProvider = Provider<DeliverableRepository>((ref) {
  return DeliverableRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(firebaseStorageProvider),
  );
});

final deliverableControllerProvider =
    AsyncNotifierProvider<DeliverableController, List<DeliverableModel>>(
      DeliverableController.new,
    );

final deliverableVersionsProvider =
    FutureProvider<List<DeliverableVersionModel>>((ref) {
      return ref.watch(deliverableRepositoryProvider).getVersions();
    });

final deliverableAnnotationsProvider =
    AsyncNotifierProvider<
      DeliverableAnnotationController,
      List<DeliverableAnnotationModel>
    >(DeliverableAnnotationController.new);

final deliverablesByProjectProvider =
    Provider.family<AsyncValue<List<DeliverableModel>>, String>((
      ref,
      projectId,
    ) {
      return ref.watch(deliverableControllerProvider).whenData((deliverables) {
        return deliverables
            .where((deliverable) => deliverable.projectId == projectId)
            .toList();
      });
    });

final deliverableVersionsByDeliverableProvider =
    Provider.family<List<DeliverableVersionModel>, String>((
      ref,
      deliverableId,
    ) {
      final versions = ref.watch(deliverableVersionsProvider).value;
      if (versions == null) return const <DeliverableVersionModel>[];
      return versions
          .where((version) => version.deliverableId == deliverableId)
          .toList()
        ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    });

final deliverableAnnotationsByVersionProvider =
    Provider.family<List<DeliverableAnnotationModel>, String>((ref, versionId) {
      final annotations = ref.watch(deliverableAnnotationsProvider).value;
      if (annotations == null) return const <DeliverableAnnotationModel>[];
      return annotations
          .where((annotation) => annotation.deliverableVersionId == versionId)
          .toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime(1900);
          final bDate = b.createdAt ?? DateTime(1900);
          return aDate.compareTo(bDate);
        });
    });

class DeliverableController extends AsyncNotifier<List<DeliverableModel>> {
  @override
  Future<List<DeliverableModel>> build() {
    return ref.watch(deliverableRepositoryProvider).getDeliverables();
  }

  Future<void> createDeliverable({
    required String projectId,
    required String clientId,
    required String title,
    required String description,
    required String kind,
    required String fileName,
    required String mimeType,
    String externalUrl = '',
    Uint8List? bytes,
  }) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) throw StateError('Utilisateur non connecté');

    final now = DateTime.now();
    final deliverableId = ref
        .read(deliverableRepositoryProvider)
        .createDeliverableId(uid);
    final storageUrl = bytes == null
        ? ''
        : await ref
              .read(deliverableRepositoryProvider)
              .uploadVersionFile(
                professionalUid: uid,
                clientId: clientId,
                deliverableId: deliverableId,
                fileName: fileName,
                mimeType: mimeType,
                bytes: bytes,
              );

    final deliverable = DeliverableModel(
      id: deliverableId,
      projectId: projectId,
      clientId: clientId,
      professionalUid: uid,
      title: title,
      description: description,
      kind: kind,
      currentVersion: 1,
      status: 'awaitingReview',
      createdAt: now,
      updatedAt: now,
    );
    final version = DeliverableVersionModel(
      id: '${deliverableId}_v1',
      deliverableId: deliverableId,
      projectId: projectId,
      clientId: clientId,
      professionalUid: uid,
      versionNumber: 1,
      storageUrl: storageUrl,
      externalUrl: externalUrl,
      fileName: fileName,
      mimeType: mimeType,
      uploadedAt: now,
      uploadedBy: uid,
      status: 'awaitingReview',
    );

    await ref
        .read(deliverableRepositoryProvider)
        .setDeliverableWithVersion(deliverable: deliverable, version: version);
    await _upsertValidationAction(deliverable, version);
    state = AsyncValue.data([deliverable, ...(state.value ?? [])]);
    ref.invalidate(deliverableVersionsProvider);
    ref.invalidate(clientPortalDeliverablesProvider);
    ref.invalidate(clientPortalDeliverableVersionsProvider);
  }

  Future<void> addVersion({
    required DeliverableModel deliverable,
    required String fileName,
    required String mimeType,
    String externalUrl = '',
    Uint8List? bytes,
  }) async {
    final now = DateTime.now();
    final nextVersion = deliverable.currentVersion + 1;
    final storageUrl = bytes == null
        ? ''
        : await ref
              .read(deliverableRepositoryProvider)
              .uploadVersionFile(
                professionalUid: deliverable.professionalUid,
                clientId: deliverable.clientId,
                deliverableId: deliverable.id,
                fileName: fileName,
                mimeType: mimeType,
                bytes: bytes,
              );
    final updatedDeliverable = deliverable.copyWith(
      currentVersion: nextVersion,
      status: 'awaitingReview',
      updatedAt: now,
    );
    final version = DeliverableVersionModel(
      id: '${deliverable.id}_v$nextVersion',
      deliverableId: deliverable.id,
      projectId: deliverable.projectId,
      clientId: deliverable.clientId,
      professionalUid: deliverable.professionalUid,
      versionNumber: nextVersion,
      storageUrl: storageUrl,
      externalUrl: externalUrl,
      fileName: fileName,
      mimeType: mimeType,
      uploadedAt: now,
      uploadedBy: deliverable.professionalUid,
      status: 'awaitingReview',
    );

    await ref
        .read(deliverableRepositoryProvider)
        .updateDeliverableWithVersion(
          deliverable: updatedDeliverable,
          version: version,
        );
    await _upsertValidationAction(updatedDeliverable, version);
    final current = state.value ?? const <DeliverableModel>[];
    state = AsyncValue.data(
      current
          .map(
            (item) =>
                item.id == updatedDeliverable.id ? updatedDeliverable : item,
          )
          .toList(),
    );
    ref.invalidate(deliverableVersionsProvider);
    ref.invalidate(clientPortalDeliverablesProvider);
    ref.invalidate(clientPortalDeliverableVersionsProvider);
  }

  Future<void> _upsertValidationAction(
    DeliverableModel deliverable,
    DeliverableVersionModel version,
  ) async {
    await ref
        .read(projectActionControllerProvider.notifier)
        .addAction(
          ClientActionModel(
            id: _validationActionId(deliverable.id, version.versionNumber),
            professionalUid: deliverable.professionalUid,
            clientId: deliverable.clientId,
            projectId: deliverable.projectId,
            title: 'Valider ${deliverable.title} V${version.versionNumber}',
            description: deliverable.description,
            assignedTo: 'client',
            type: 'validation',
            priority: 'high',
            status: 'pending',
            visibleToClient: true,
            createdAt: version.uploadedAt,
            updatedAt: DateTime.now(),
          ),
        );
  }
}

String validationActionId(String deliverableId, int versionNumber) {
  return _validationActionId(deliverableId, versionNumber);
}

String _validationActionId(String deliverableId, int versionNumber) {
  return 'deliverable_${deliverableId}_v${versionNumber}_validation';
}

class DeliverableAnnotationController
    extends AsyncNotifier<List<DeliverableAnnotationModel>> {
  @override
  Future<List<DeliverableAnnotationModel>> build() {
    return ref.watch(deliverableRepositoryProvider).getAnnotations();
  }

  Future<void> addAnnotation(DeliverableAnnotationModel annotation) async {
    final now = DateTime.now();
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    final prepared = annotation.copyWith(
      authorUid: annotation.authorUid.isNotEmpty ? annotation.authorUid : uid,
      createdAt: annotation.createdAt ?? now,
      resolved: false,
      clearResolvedAt: true,
    );

    final current = state.value ?? const <DeliverableAnnotationModel>[];
    state = AsyncValue.data([...current, prepared]);

    await ref.read(deliverableRepositoryProvider).setAnnotation(prepared);
    ref.invalidate(clientPortalDeliverableAnnotationsProvider);
  }

  Future<void> resolveAnnotation(DeliverableAnnotationModel annotation) async {
    final resolved = annotation.copyWith(
      resolved: true,
      resolvedAt: DateTime.now(),
    );
    final current = state.value ?? const <DeliverableAnnotationModel>[];
    state = AsyncValue.data(
      current.map((item) => item.id == resolved.id ? resolved : item).toList(),
    );

    await ref.read(deliverableRepositoryProvider).setAnnotation(resolved);
    ref.invalidate(clientPortalDeliverableAnnotationsProvider);
  }
}
