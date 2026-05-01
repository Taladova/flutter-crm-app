import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/repositories/client_repository.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(
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
    error: (_, __) => null,
  );
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

  Future<void> resetClients() async {
    final repository = ref.read(clientRepositoryProvider);
    await repository.resetClients();
    state = AsyncValue.data(await repository.getClients());
  }
}
