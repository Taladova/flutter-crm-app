import '../models/client_note_model.dart';
import '../services/firestore_service.dart';

class ClientNoteRepository {
  const ClientNoteRepository({required this.firestoreService});

  final FirestoreService firestoreService;

  Future<List<ClientNoteModel>> getNotes() async {
    final snapshot = await firestoreService
        .userCollection('client_notes')
        .get();
    final notes = snapshot.docs.map((doc) {
      return ClientNoteModel.fromJson({...doc.data(), 'id': doc.id});
    }).toList();

    notes.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1900);
      final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });

    return notes;
  }

  Future<void> setNote(ClientNoteModel note) async {
    await firestoreService
        .userCollection('client_notes')
        .doc(note.id)
        .set(note.toJson());
  }

  Future<void> deleteNote(String id) async {
    await firestoreService.userCollection('client_notes').doc(id).delete();
  }
}
