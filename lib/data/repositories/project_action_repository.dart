import '../models/client_action_model.dart';
import '../services/firestore_service.dart';

class ProjectActionRepository {
  const ProjectActionRepository({required this.firestoreService});

  final FirestoreService firestoreService;

  Future<List<ClientActionModel>> getActions() async {
    final snapshot = await firestoreService
        .userCollection('project_actions')
        .get();

    final actions = snapshot.docs.map((doc) {
      return ClientActionModel.fromJson({...doc.data(), 'id': doc.id});
    }).toList();

    actions.sort((a, b) {
      final aDate = a.dueDate ?? a.createdAt ?? DateTime(9999);
      final bDate = b.dueDate ?? b.createdAt ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });

    return actions;
  }

  Future<void> addAction(ClientActionModel action) async {
    await firestoreService
        .userCollection('project_actions')
        .doc(action.id)
        .set(action.toJson());
  }

  Future<void> updateAction(ClientActionModel action) async {
    await firestoreService
        .userCollection('project_actions')
        .doc(action.id)
        .set(action.toJson());
  }

  Future<void> deleteAction(String id) async {
    await firestoreService.userCollection('project_actions').doc(id).delete();
  }
}
