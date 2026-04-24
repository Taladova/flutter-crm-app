import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/project_model.dart';
import '../../../data/repositories/project_repository.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return const ProjectRepository();
});

final projectControllerProvider =
    AsyncNotifierProvider<ProjectController, List<ProjectModel>>(
  ProjectController.new,
);

final projectByIdProvider = Provider.family<ProjectModel?, String>(
  (ref, projectId) {
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
      error: (_, __) => null,
    );
  },
);

class ProjectController extends AsyncNotifier<List<ProjectModel>> {
  @override
  Future<List<ProjectModel>> build() async {
    final repository = ref.watch(projectRepositoryProvider);
    return repository.getProjects();
  }

  Future<void> addProject(ProjectModel project) async {
    final currentProjects = state.value ?? [];

    final updatedProjects = [
      project,
      ...currentProjects,
    ];

    state = AsyncValue.data(updatedProjects);

    await ref.read(projectRepositoryProvider).saveProjects(updatedProjects);
  }
}