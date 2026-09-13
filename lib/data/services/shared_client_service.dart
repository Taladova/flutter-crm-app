import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/client_message_model.dart';
import '../models/client_model.dart';

/// Publishes a read/write "client space" for a client so they can look up
/// their own record with a short code (no Deskly account needed) and
/// exchange messages with the freelancer who owns them.
class SharedClientService {
  SharedClientService({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection('shared_clients');

  Future<String> publish({
    required String ownerUid,
    required ClientModel client,
  }) async {
    var token = client.shareToken;

    // Resolve against every shared_clients doc this professional already
    // owns (single-field query, no composite index needed) and match in
    // memory — this is the same resolution strategy the client side uses,
    // so both sides converge on the same existing doc instead of each
    // silently minting a new token when a lookup misses.
    if (token.isEmpty) {
      final owned = await _collection
          .where('ownerUid', isEqualTo: ownerUid)
          .get();
      token = _findExistingToken(
        docs: owned.docs,
        clientId: client.id,
        clientEmail: client.email,
      );
    }

    if (token.isEmpty) token = _generateToken();

    // TEMP DIAGNOSTIC LOG — see clientflow_pro professional/client link audit.
    // ignore: avoid_print
    print('[chat][pro] sharedClientId=$token');

    await _collection.doc(token).set({
      'ownerUid': ownerUid,
      'clientId': client.id,
      'clientName': client.name,
      'clientEmail': client.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return token;
  }

  /// Matches by clientId first (exact — both sides derive it from the same
  /// source value), then by a trimmed/lowercased email as a fallback so
  /// casing or whitespace differences don't cause a spurious new token.
  String _findExistingToken({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String clientId,
    required String clientEmail,
  }) {
    if (clientId.isNotEmpty) {
      for (final doc in docs) {
        if (doc.data()['clientId'] == clientId) return doc.id;
      }
    }

    final normalizedEmail = clientEmail.trim().toLowerCase();
    if (normalizedEmail.isNotEmpty) {
      for (final doc in docs) {
        final docEmail = '${doc.data()['clientEmail'] ?? ''}'
            .trim()
            .toLowerCase();
        if (docEmail == normalizedEmail) return doc.id;
      }
    }

    return '';
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

  Stream<List<ClientMessageModel>> messagesStream(String token) {
    return _collection
        .doc(token)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClientMessageModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<ClientMessageModel?> lastMessageStream(String token) {
    return _collection
        .doc(token)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return ClientMessageModel.fromMap(doc.id, doc.data());
        });
  }

  Future<void> sendMessage({
    required String token,
    required String senderType,
    required String text,
    String? senderUid,
  }) async {
    // TEMP DIAGNOSTIC LOG — see clientflow_pro professional/client link audit.
    // ignore: avoid_print
    print(
      '[chat] shared_clients/$token/messages senderType=$senderType '
      'senderUid=$senderUid',
    );
    await _collection.doc(token).collection('messages').add({
      'senderType': senderType,
      if (senderUid != null && senderUid.isNotEmpty) 'senderUid': senderUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _generateToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
