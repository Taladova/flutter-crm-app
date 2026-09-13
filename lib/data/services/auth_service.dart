import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth;

  AuthService(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await userCredential.user?.updateDisplayName(name);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .set({
          'name': name,
          'email': email,
          'role': 'professional',
          'createdAt': Timestamp.now(),
        });
  }

  Future<String> currentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'guest';

    final firestore = FirebaseFirestore.instance;

    try {
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userRole = userDoc.data()?['role'] as String?;
      if (userRole == 'client' || userRole == 'professional') {
        return userRole!;
      }
    } catch (_) {
      // Continue with the dedicated client account lookup below.
    }

    try {
      final clientDoc = await firestore
          .collection('client_accounts')
          .doc(user.uid)
          .get();
      if (clientDoc.exists) return 'client';
    } catch (_) {
      // Existing professional accounts created before roles should still be
      // able to sign in even if role lookups are temporarily unavailable.
    }

    return 'professional';
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
