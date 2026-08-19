import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/project_model.dart';
import '../models/task_model.dart';

/// Publishes and reads read-only "client portal" snapshots of a project,
/// stored in the top-level `shared_projects` collection so a client without
/// a Deskly account can look up their project's status with a short code.
class SharedProjectService {
  SharedProjectService({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection('shared_projects');

  /// Publishes (or refreshes) a public snapshot for [project] and returns
  /// the share code the client can use to look it up.
  Future<String> publish({
    required String ownerUid,
    required ProjectModel project,
    required List<TaskModel> tasks,
  }) async {
    final token = project.shareToken.isNotEmpty ? project.shareToken : _generateToken();

    await _collection.doc(token).set({
      'ownerUid': ownerUid,
      'projectId': project.id,
      'title': project.title,
      'clientName': project.clientName,
      'type': project.type,
      'status': project.status,
      'budget': project.budget,
      'deadline': project.deadline,
      'progress': project.progress,
      'tasks': tasks
          .map((task) => {'title': task.title, 'status': task.status})
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return token;
  }

  Future<void> revoke(String token) async {
    if (token.isEmpty) return;
    await _collection.doc(token).delete();
  }

  Future<Map<String, dynamic>?> fetch(String token) async {
    final doc = await _collection.doc(token.trim().toUpperCase()).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  String _generateToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
