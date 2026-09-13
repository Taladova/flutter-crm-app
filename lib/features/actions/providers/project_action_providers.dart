import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client_action_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/repositories/project_action_repository.dart';
import '../../../data/services/project_waiting_status_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../client_portal/providers/client_portal_providers.dart';
import '../../projects/providers/project_progress_sync.dart';
import '../../timeline/providers/timeline_providers.dart';

final projectActionRepositoryProvider = Provider<ProjectActionRepository>((
  ref,
) {
  return ProjectActionRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});

final projectActionControllerProvider =
    AsyncNotifierProvider<ProjectActionController, List<ClientActionModel>>(
      ProjectActionController.new,
    );

final projectActionsByProjectProvider =
    Provider.family<AsyncValue<List<ClientActionModel>>, String>((
      ref,
      projectId,
    ) {
      final actionsState = ref.watch(projectActionControllerProvider);

      return actionsState.whenData((actions) {
        final filtered = actions
            .where((action) => action.projectId == projectId)
            .toList();

        filtered.sort((a, b) {
          if (a.status != b.status) {
            return a.status == 'pending' ? -1 : 1;
          }

          final aDate = a.dueDate ?? a.createdAt ?? DateTime(9999);
          final bDate = b.dueDate ?? b.createdAt ?? DateTime(9999);
          return aDate.compareTo(bDate);
        });

        return filtered;
      });
    });

final projectWaitingStatusServiceProvider =
    Provider<ProjectWaitingStatusService>((ref) {
      return const ProjectWaitingStatusService();
    });

final projectWaitingSummaryProvider =
    Provider.family<AsyncValue<ProjectWaitingSummary>, String>((
      ref,
      projectId,
    ) {
      final actionsState = ref.watch(
        projectActionsByProjectProvider(projectId),
      );

      return actionsState.whenData((actions) {
        return ref
            .watch(projectWaitingStatusServiceProvider)
            .evaluate(actions: actions);
      });
    });

class ProjectActionController extends AsyncNotifier<List<ClientActionModel>> {
  @override
  Future<List<ClientActionModel>> build() async {
    return ref.watch(projectActionRepositoryProvider).getActions();
  }

  Future<void> addAction(ClientActionModel action) async {
    final now = DateTime.now();
    final prepared = action.copyWith(
      createdAt: action.createdAt ?? now,
      updatedAt: now,
      professionalUid: action.professionalUid.isNotEmpty
          ? action.professionalUid
          : ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
    );

    final current = state.value ?? const <ClientActionModel>[];
    final updatedList = [prepared, ...current];
    state = AsyncValue.data(updatedList);

    await ref.read(projectActionRepositoryProvider).addAction(prepared);
    await _syncToClientPortal(prepared);
    await _recalculateStage(prepared, updatedList);
    await syncProjectProgress(ref, prepared.projectId, actions: updatedList);
  }

  Future<void> updateAction(ClientActionModel action) async {
    final prepared = action.copyWith(updatedAt: DateTime.now());
    final current = state.value ?? const <ClientActionModel>[];
    final updatedList = current
        .map((existing) => existing.id == prepared.id ? prepared : existing)
        .toList();
    state = AsyncValue.data(updatedList);

    await ref.read(projectActionRepositoryProvider).updateAction(prepared);
    await _syncToClientPortal(prepared);
    await _recalculateStage(prepared, updatedList);
    await syncProjectProgress(ref, prepared.projectId, actions: updatedList);
  }

  Future<void> completeAction(ClientActionModel action) async {
    await updateAction(
      action.copyWith(status: 'completed', completedAt: DateTime.now()),
    );
  }

  Future<void> deleteAction(ClientActionModel action) async {
    final current = state.value ?? const <ClientActionModel>[];
    final updatedList = current
        .where((existing) => existing.id != action.id)
        .toList();
    state = AsyncValue.data(updatedList);

    await ref.read(projectActionRepositoryProvider).deleteAction(action.id);
    await ref
        .read(clientPortalServiceProvider)
        .deleteActionForClientAccounts(action: action);
    await _recalculateStage(action, updatedList);
    await syncProjectProgress(ref, action.projectId, actions: updatedList);
  }

  Future<void> _syncToClientPortal(ClientActionModel action) async {
    if (action.professionalUid.isEmpty || action.projectId.isEmpty) return;

    await ref
        .read(clientPortalServiceProvider)
        .syncProjectActionForClientAccounts(action: action);
  }

  /// Reflects an action's completion (or reopening/removal) on the timeline
  /// step it's linked to — see TimelineController.recalculateStageFromActions.
  Future<void> _recalculateStage(
    ClientActionModel action,
    List<ClientActionModel> currentActions,
  ) async {
    if (!action.hasStage) return;

    await ref
        .read(timelineControllerProvider.notifier)
        .recalculateStageFromActions(
          projectId: action.projectId,
          stageId: action.stageId,
          projectActions: currentActions
              .where((item) => item.projectId == action.projectId)
              .toList(),
        );
  }
}
