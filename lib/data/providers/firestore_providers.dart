import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_service.dart';
import '../services/shared_client_service.dart';
import '../services/shared_project_service.dart';
import '../../features/auth/providers/auth_providers.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final sharedProjectServiceProvider = Provider<SharedProjectService>((ref) {
  return SharedProjectService(firestore: ref.watch(firestoreProvider));
});

final sharedClientServiceProvider = Provider<SharedClientService>((ref) {
  return SharedClientService(firestore: ref.watch(firestoreProvider));
});

/// Resolves the current user's display name, falling back to the Firestore
/// user document for accounts whose Firebase Auth profile has no name set.
final userDisplayNameProvider = FutureProvider<String>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return 'Utilisateur';

  final authName = user.displayName;
  if (authName != null && authName.trim().isNotEmpty) {
    return authName;
  }

  final doc = await ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .get();

  final firestoreName = doc.data()?['name'] as String?;
  if (firestoreName != null && firestoreName.trim().isNotEmpty) {
    return firestoreName;
  }

  return 'Utilisateur';
});
