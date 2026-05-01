import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService({
    required this.firestore,
    required this.auth,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  String get userId {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> userCollection(String name) {
    return firestore.collection('users').doc(userId).collection(name);
  }
}