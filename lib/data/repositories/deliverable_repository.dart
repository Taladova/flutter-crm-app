import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/deliverable_annotation_model.dart';
import '../models/deliverable_model.dart';
import '../models/deliverable_version_model.dart';
import '../services/firestore_service.dart';

class DeliverableRepository {
  const DeliverableRepository({
    required this.firestoreService,
    required this.firestore,
    required this.storage,
  });

  final FirestoreService firestoreService;
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  Future<List<DeliverableModel>> getDeliverables() async {
    final snapshot = await firestoreService
        .userCollection('deliverables')
        .get();

    final deliverables = snapshot.docs
        .map((doc) => DeliverableModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();

    deliverables.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1900);
      final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });
    return deliverables;
  }

  Future<List<DeliverableVersionModel>> getVersions() async {
    final snapshot = await firestoreService
        .userCollection('deliverable_versions')
        .get();

    final versions = snapshot.docs
        .map(
          (doc) =>
              DeliverableVersionModel.fromJson({...doc.data(), 'id': doc.id}),
        )
        .toList();

    versions.sort((a, b) {
      if (a.deliverableId != b.deliverableId) {
        return a.deliverableId.compareTo(b.deliverableId);
      }
      return b.versionNumber.compareTo(a.versionNumber);
    });
    return versions;
  }

  Future<List<DeliverableAnnotationModel>> getAnnotations() async {
    final snapshot = await firestoreService
        .userCollection('deliverable_annotations')
        .get();

    final annotations = snapshot.docs
        .map(
          (doc) => DeliverableAnnotationModel.fromJson({
            ...doc.data(),
            'id': doc.id,
          }),
        )
        .toList();

    annotations.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1900);
      final bDate = b.createdAt ?? DateTime(1900);
      return aDate.compareTo(bDate);
    });
    return annotations;
  }

  String createDeliverableId(String professionalUid) {
    return firestore
        .collection('users')
        .doc(professionalUid)
        .collection('deliverables')
        .doc()
        .id;
  }

  Future<String> uploadVersionFile({
    required String professionalUid,
    required String clientId,
    required String deliverableId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('Le fichier sélectionné est vide.');
    }

    final safeFileName = fileName.replaceAll('/', '_');
    final ref = storage
        .ref()
        .child('users')
        .child(professionalUid)
        .child('clients')
        .child(clientId)
        .child('deliverables')
        .child(deliverableId)
        .child('${DateTime.now().millisecondsSinceEpoch}_$safeFileName');
    await ref.putData(bytes, SettableMetadata(contentType: mimeType));
    return ref.getDownloadURL();
  }

  Future<void> setDeliverableWithVersion({
    required DeliverableModel deliverable,
    required DeliverableVersionModel version,
  }) async {
    final batch = firestore.batch();
    final userRef = firestore
        .collection('users')
        .doc(deliverable.professionalUid);

    batch.set(
      userRef.collection('deliverables').doc(deliverable.id),
      deliverable.toJson(),
    );
    batch.set(
      userRef.collection('deliverable_versions').doc(version.id),
      version.toJson(),
    );

    final sharedClientId = await _sharedClientIdForDeliverable(deliverable);
    // ignore: avoid_print
    print(
      '[validation][pro][create]\n'
      'projectId=${deliverable.projectId}\n'
      'validationId=${deliverable.id}\n'
      'clientId=${deliverable.clientId}\n'
      'sharedClientId=$sharedClientId\n'
      'firestorePath=users/${deliverable.professionalUid}/deliverables/${deliverable.id}\n'
      'status=${deliverable.status}\n'
      'visibleToClient=${deliverable.visibleToClient}',
    );
    await batch.commit();
  }

  Future<void> updateDeliverableWithVersion({
    required DeliverableModel deliverable,
    required DeliverableVersionModel version,
  }) async {
    await setDeliverableWithVersion(deliverable: deliverable, version: version);
  }

  Future<String> _sharedClientIdForDeliverable(
    DeliverableModel deliverable,
  ) async {
    final accounts = await _matchingClientAccounts(
      professionalUid: deliverable.professionalUid,
      clientId: deliverable.clientId,
      projectId: deliverable.projectId,
    );

    for (final account in accounts) {
      final sharedClientId = '${account.data()['sharedClientId'] ?? ''}'.trim();
      if (sharedClientId.isNotEmpty) return sharedClientId;
    }

    final shared = await firestore
        .collection('shared_clients')
        .where('professionalId', isEqualTo: deliverable.professionalUid)
        .where('clientId', isEqualTo: deliverable.clientId)
        .limit(1)
        .get();
    if (shared.docs.isNotEmpty) return shared.docs.first.id;

    return '';
  }

  Future<void> setAnnotation(DeliverableAnnotationModel annotation) async {
    final batch = firestore.batch();
    final userRef = firestore
        .collection('users')
        .doc(annotation.professionalUid);

    batch.set(
      userRef.collection('deliverable_annotations').doc(annotation.id),
      annotation.toJson(),
      SetOptions(merge: true),
    );

    final accounts = await _matchingClientAccounts(
      professionalUid: annotation.professionalUid,
      clientId: '',
      projectId: annotation.projectId,
    );

    for (final account in accounts) {
      batch.set(
        account.reference
            .collection('deliverable_annotations')
            .doc(annotation.id),
        annotation.toJson(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _matchingClientAccounts({
    required String professionalUid,
    required String clientId,
    required String projectId,
  }) async {
    final snapshot = await firestore
        .collection('client_accounts')
        .where('professionalId', isEqualTo: professionalUid)
        .where('projectIds', arrayContains: projectId)
        .get();

    return snapshot.docs.where((doc) {
      final data = doc.data();
      return clientId.isEmpty || data['clientId'] == clientId;
    }).toList();
  }
}
