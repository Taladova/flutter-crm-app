import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/repositories/project_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../clients/providers/client_providers.dart';
import '../../client_portal/providers/client_portal_providers.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});

final projectControllerProvider =
    AsyncNotifierProvider<ProjectController, List<ProjectModel>>(
      ProjectController.new,
    );

final projectByIdProvider = Provider.family<ProjectModel?, String>((
  ref,
  projectId,
) {
  final projectsState = ref.watch(projectControllerProvider);

  return projectsState.when(
    data: (projects) {
      try {
        return projects.firstWhere((project) => project.id == projectId);
      } catch (_) {
        return null;
      }
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

class ProjectController extends AsyncNotifier<List<ProjectModel>> {
  @override
  Future<List<ProjectModel>> build() async {
    final repository = ref.watch(projectRepositoryProvider);
    return repository.getProjects();
  }

  Future<void> addProject(ProjectModel project) async {
    final currentProjects = state.value ?? [];
    final updatedProjects = [project, ...currentProjects];

    state = AsyncValue.data(updatedProjects);

    await ref.read(projectRepositoryProvider).addProject(project);
    await _syncProjectToClientPortal(project);
  }

  Future<void> updateProject(ProjectModel project) async {
    final currentProjects = state.value ?? [];
    final updatedProjects = currentProjects
        .map((existing) => existing.id == project.id ? project : existing)
        .toList();

    state = AsyncValue.data(updatedProjects);

    await ref.read(projectRepositoryProvider).updateProject(project);
    await _syncProjectToClientPortal(project);
  }

  Future<void> deleteProject(String id) async {
    final currentProjects = state.value ?? [];
    final updatedProjects = currentProjects
        .where((project) => project.id != id)
        .toList();

    state = AsyncValue.data(updatedProjects);

    await ref.read(projectRepositoryProvider).deleteProject(id);
  }

  Future<void> clearProjects() async {
    final repository = ref.read(projectRepositoryProvider);
    await repository.clearProjects();
    state = const AsyncValue.data([]);
  }

  Future<void> _syncProjectToClientPortal(ProjectModel project) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null || project.id.isEmpty) return;
    final clients = ref.read(clientControllerProvider).value ?? [];
    final clientId = _clientIdFromName(clients, project.clientName);

    await ref
        .read(clientPortalServiceProvider)
        .syncProjectForClientAccounts(
          professionalId: uid,
          project: project,
          clientId: clientId,
        );
  }

  String _clientIdFromName(List<ClientModel> clients, String clientName) {
    final normalizedName = clientName.trim().toLowerCase();
    for (final client in clients) {
      if (client.name.trim().toLowerCase() == normalizedName) {
        return client.id;
      }
    }
    return '';
  }
}
