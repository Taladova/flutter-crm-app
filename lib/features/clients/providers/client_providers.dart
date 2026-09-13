import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client_message_model.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/client_note_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/repositories/client_note_repository.dart';
import '../../../data/repositories/client_repository.dart';

final clientMessagesProvider =
    StreamProvider.family<List<ClientMessageModel>, String>((ref, token) {
      return ref.watch(sharedClientServiceProvider).messagesStream(token);
    });

final clientLastMessageProvider =
    StreamProvider.family<ClientMessageModel?, String>((ref, token) {
      return ref.watch(sharedClientServiceProvider).lastMessageStream(token);
    });

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});

final clientNoteRepositoryProvider = Provider<ClientNoteRepository>((ref) {
  return ClientNoteRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});

final clientControllerProvider =
    AsyncNotifierProvider<ClientController, List<ClientModel>>(
      ClientController.new,
    );

final clientByIdProvider = Provider.family<ClientModel?, String>((
  ref,
  clientId,
) {
  final clientsState = ref.watch(clientControllerProvider);

  return clientsState.when(
    data: (clients) {
      try {
        return clients.firstWhere((client) => client.id == clientId);
      } catch (_) {
        return null;
      }
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

final clientNoteControllerProvider =
    AsyncNotifierProvider<ClientNoteController, List<ClientNoteModel>>(
      ClientNoteController.new,
    );

final clientNotesByClientProvider =
    Provider.family<List<ClientNoteModel>, String>((ref, clientId) {
      final state = ref.watch(clientNoteControllerProvider);
      return state.value?.where((note) => note.clientId == clientId).toList() ??
          const <ClientNoteModel>[];
    });

class ClientController extends AsyncNotifier<List<ClientModel>> {
  @override
  Future<List<ClientModel>> build() async {
    final repository = ref.watch(clientRepositoryProvider);
    return repository.getClients();
  }

  Future<void> addClient(ClientModel client) async {
    final currentClients = state.value ?? [];
    final updatedClients = [client, ...currentClients];

    state = AsyncValue.data(updatedClients);

    await ref.read(clientRepositoryProvider).addClient(client);
  }

  Future<void> updateClient(ClientModel client) async {
    final currentClients = state.value ?? [];
    final updatedClients = currentClients
        .map((existing) => existing.id == client.id ? client : existing)
        .toList();

    state = AsyncValue.data(updatedClients);

    await ref.read(clientRepositoryProvider).updateClient(client);
  }

  Future<void> deleteClient(String id) async {
    final currentClients = state.value ?? [];
    final updatedClients = currentClients
        .where((client) => client.id != id)
        .toList();

    state = AsyncValue.data(updatedClients);

    await ref.read(clientRepositoryProvider).deleteClient(id);
  }

  Future<void> clearClients() async {
    final repository = ref.read(clientRepositoryProvider);
    await repository.clearClients();
    state = const AsyncValue.data([]);
  }
}

class ClientNoteController extends AsyncNotifier<List<ClientNoteModel>> {
  @override
  Future<List<ClientNoteModel>> build() {
    return ref.watch(clientNoteRepositoryProvider).getNotes();
  }

  Future<void> addNote(ClientNoteModel note) async {
    final now = DateTime.now();
    final prepared = note.copyWith(
      createdAt: note.createdAt ?? now,
      updatedAt: now,
    );
    final current = state.value ?? const <ClientNoteModel>[];
    state = AsyncValue.data([prepared, ...current]);

    await ref.read(clientNoteRepositoryProvider).setNote(prepared);
  }

  Future<void> updateNote(ClientNoteModel note) async {
    final prepared = note.copyWith(updatedAt: DateTime.now());
    final current = state.value ?? const <ClientNoteModel>[];
    state = AsyncValue.data(
      current.map((item) => item.id == prepared.id ? prepared : item).toList(),
    );

    await ref.read(clientNoteRepositoryProvider).setNote(prepared);
  }

  Future<void> deleteNote(String id) async {
    final current = state.value ?? const <ClientNoteModel>[];
    state = AsyncValue.data(current.where((note) => note.id != id).toList());

    await ref.read(clientNoteRepositoryProvider).deleteNote(id);
  }

  Future<void> migrateLegacyNote(ClientModel client) async {
    final legacyContent = client.notes.trim();
    if (legacyContent.isEmpty) return;

    final legacyId = 'legacy_${client.id}';
    final current = state.value ?? const <ClientNoteModel>[];
    final alreadyMigrated = current.any((note) => note.id == legacyId);
    if (alreadyMigrated) return;

    await addNote(
      ClientNoteModel(
        id: legacyId,
        clientId: client.id,
        content: legacyContent,
      ),
    );
  }
}
