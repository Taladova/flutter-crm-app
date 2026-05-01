import '../models/project_model.dart';
import '../services/firestore_service.dart';

class ProjectRepository {
  const ProjectRepository({
    required this.firestoreService,
  });

  final FirestoreService firestoreService;

  Future<List<ProjectModel>> getProjects() async {
    final snapshot = await firestoreService.userCollection('projects').get();

    return snapshot.docs.map((doc) {
      return ProjectModel.fromJson(doc.data());
    }).toList();
  }

  Future<void> addProject(ProjectModel project) async {
    await firestoreService
        .userCollection('projects')
        .doc(project.id)
        .set(project.toJson());
  }

  Future<ProjectModel?> getProjectById(String id) async {
    final doc = await firestoreService.userCollection('projects').doc(id).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return ProjectModel.fromJson(doc.data()!);
  }

  Future<void> resetProjects() async {
    final collection = firestoreService.userCollection('projects');
    final snapshot = await collection.get();

    final batch = firestoreService.firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}