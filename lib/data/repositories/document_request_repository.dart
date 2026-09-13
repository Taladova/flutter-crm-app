import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/document_request_model.dart';
import '../services/firestore_service.dart';

class DocumentRequestRepository {
  const DocumentRequestRepository({required this.firestoreService});

  final FirestoreService firestoreService;

  Future<List<DocumentRequestModel>> getRequests() async {
    final snapshot = await firestoreService
        .userCollection('document_requests')
        .get();
    return _sortedRequestsFromDocs(snapshot.docs);
  }

  Stream<List<DocumentRequestModel>> requestsStream() {
    return firestoreService
        .userCollection('document_requests')
        .snapshots()
        .map((snapshot) => _sortedRequestsFromDocs(snapshot.docs));
  }

  List<DocumentRequestModel> _sortedRequestsFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final requests = docs
        .map(
          (doc) => DocumentRequestModel.fromJson({...doc.data(), 'id': doc.id}),
        )
        .toList();

    requests.sort((a, b) {
      final aDate = a.dueDate ?? a.createdAt ?? DateTime(9999);
      final bDate = b.dueDate ?? b.createdAt ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return requests;
  }

  Future<void> setRequest(DocumentRequestModel request) async {
    await firestoreService
        .userCollection('document_requests')
        .doc(request.id)
        .set(request.toJson());
  }

  Future<void> deleteRequest(String id) async {
    await firestoreService.userCollection('document_requests').doc(id).delete();
  }
}
