import '../models/client_model.dart';
import '../services/firestore_service.dart';
import '../mock/mock_clients.dart';

class ClientRepository {
  const ClientRepository({required this.firestoreService});

  final FirestoreService firestoreService;

  Future<List<ClientModel>> getClients() async {
    final snapshot = await firestoreService.userCollection('clients').get();

    return snapshot.docs.map((doc) {
      return ClientModel.fromJson(doc.data());
    }).toList();
  }

  Future<void> saveClients(List<ClientModel> clients) async {
    final batch = firestoreService.firestore.batch();
    final collection = firestoreService.userCollection('clients');

    for (final client in clients) {
      final docRef = collection.doc(client.id);
      batch.set(docRef, client.toJson());
    }

    await batch.commit();
  }

  Future<void> addClient(ClientModel client) async {
    await firestoreService
        .userCollection('clients')
        .doc(client.id)
        .set(client.toJson());
  }

  Future<ClientModel?> getClientById(String id) async {
    final doc = await firestoreService.userCollection('clients').doc(id).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return ClientModel.fromJson(doc.data()!);
  }

  Future<void> resetClients() async {
    final collection = firestoreService.userCollection('clients');
    final snapshot = await collection.get();

    final batch = firestoreService.firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    for (final client in mockClients) {
      batch.set(collection.doc(client.id), client.toJson());
    }

    await batch.commit();
  }
}
