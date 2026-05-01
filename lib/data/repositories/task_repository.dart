import '../models/task_model.dart';
import '../services/firestore_service.dart';

class TaskRepository {
  const TaskRepository({
    required this.firestoreService,
  });

  final FirestoreService firestoreService;

  Future<List<TaskModel>> getTasks() async {
    final snapshot = await firestoreService.userCollection('tasks').get();

    return snapshot.docs.map((doc) {
      return TaskModel.fromJson(doc.data());
    }).toList();
  }

  Future<void> addTask(TaskModel task) async {
    await firestoreService
        .userCollection('tasks')
        .doc(task.id)
        .set(task.toJson());
  }

  Future<void> updateTask(TaskModel task) async {
    await firestoreService
        .userCollection('tasks')
        .doc(task.id)
        .set(task.toJson());
  }

  Future<void> resetTasks() async {
    final collection = firestoreService.userCollection('tasks');
    final snapshot = await collection.get();

    final batch = firestoreService.firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}