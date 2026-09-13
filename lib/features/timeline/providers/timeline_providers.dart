import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client_action_model.dart';
import '../../../data/models/timeline_event_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/repositories/timeline_repository.dart';
import '../../../data/services/project_timeline_progress_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../client_portal/providers/client_portal_providers.dart';
import '../../projects/providers/project_progress_sync.dart';

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  return TimelineRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});

final projectTimelineProgressServiceProvider =
    Provider<ProjectTimelineProgressService>((ref) {
      return const ProjectTimelineProgressService();
    });

final timelineControllerProvider =
    AsyncNotifierProvider<TimelineController, List<TimelineEventModel>>(
      TimelineController.new,
    );

final timelineByProjectProvider =
    Provider.family<AsyncValue<List<TimelineEventModel>>, String>((
      ref,
      projectId,
    ) {
      final state = ref.watch(timelineControllerProvider);
      return state.whenData((events) {
        final filtered = events
            .where((event) => event.projectId == projectId)
            .toList();
        filtered.sort((a, b) => a.order.compareTo(b.order));
        return filtered;
      });
    });

class TimelineController extends AsyncNotifier<List<TimelineEventModel>> {
  @override
  Future<List<TimelineEventModel>> build() {
    return ref.watch(timelineRepositoryProvider).getEvents();
  }

  Future<void> addEvent(TimelineEventModel event) async {
    final now = DateTime.now();
    final prepared = event.copyWith(
      professionalUid: event.professionalUid.isNotEmpty
          ? event.professionalUid
          : ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
      createdAt: event.createdAt ?? now,
      updatedAt: now,
    );
    final current = state.value ?? const <TimelineEventModel>[];
    final updatedEvents = [...current, prepared]..sort(_sortEvents);
    state = AsyncValue.data(updatedEvents);

    await ref.read(timelineRepositoryProvider).setEvent(prepared);
    await _syncToClient(prepared);
    await _syncProjectFromTimeline(prepared.projectId, events: updatedEvents);
  }

  Future<void> updateEvent(TimelineEventModel event) async {
    final prepared = event.copyWith(updatedAt: DateTime.now());
    final current = state.value ?? const <TimelineEventModel>[];
    final updatedEvents =
        current.map((item) => item.id == prepared.id ? prepared : item).toList()
          ..sort(_sortEvents);
    state = AsyncValue.data(updatedEvents);

    await ref.read(timelineRepositoryProvider).setEvent(prepared);
    await _syncToClient(prepared);
    await _syncProjectFromTimeline(prepared.projectId, events: updatedEvents);
  }

  Future<void> deleteEvent(TimelineEventModel event) async {
    final current = state.value ?? const <TimelineEventModel>[];
    final updatedEvents = current.where((item) => item.id != event.id).toList();
    state = AsyncValue.data(updatedEvents);

    await ref.read(timelineRepositoryProvider).deleteEvent(event.id);
    await ref
        .read(clientPortalServiceProvider)
        .deleteTimelineEventForClientAccounts(event: event);
    await _syncProjectFromTimeline(event.projectId, events: updatedEvents);
  }

  Future<void> setCurrent(TimelineEventModel selected) async {
    final current = state.value ?? const <TimelineEventModel>[];
    final updated = current.map((event) {
      if (event.projectId != selected.projectId) return event;
      if (event.id == selected.id) return event.copyWith(status: 'current');
      if (event.status == 'current') return event.copyWith(status: 'upcoming');
      return event;
    }).toList();

    state = AsyncValue.data(updated..sort(_sortEvents));
    for (final event in updated.where(
      (e) => e.projectId == selected.projectId,
    )) {
      await ref.read(timelineRepositoryProvider).setEvent(event);
      await _syncToClient(event);
    }
    await _syncProjectFromTimeline(selected.projectId, events: updated);
  }

  Future<void> moveEvent(TimelineEventModel event, int direction) async {
    final current = state.value ?? const <TimelineEventModel>[];
    final projectEvents =
        current.where((item) => item.projectId == event.projectId).toList()
          ..sort(_sortEvents);
    final index = projectEvents.indexWhere((item) => item.id == event.id);
    final targetIndex = index + direction;
    if (index < 0 || targetIndex < 0 || targetIndex >= projectEvents.length) {
      return;
    }

    final currentOrder = projectEvents[index].order;
    final targetOrder = projectEvents[targetIndex].order;
    final first = projectEvents[index].copyWith(order: targetOrder);
    final second = projectEvents[targetIndex].copyWith(order: currentOrder);

    await updateEvent(first);
    await updateEvent(second);
  }

  /// Derives one stage's status from the actions linked to it (action.stageId
  /// == this event's id), when the stage actually has linked actions — a
  /// stage nobody has attached an action to is left entirely to the
  /// professional's manual management. Called after an action tied to a
  /// stage is completed/reopened so the timeline reflects it, which in turn
  /// feeds project.progress via the usual event mutation path.
  Future<void> recalculateStageFromActions({
    required String projectId,
    required String stageId,
    required List<ClientActionModel> projectActions,
  }) async {
    if (stageId.isEmpty) return;

    final current = state.value ?? const <TimelineEventModel>[];
    TimelineEventModel? event;
    for (final item in current) {
      if (item.id == stageId && item.projectId == projectId) {
        event = item;
        break;
      }
    }
    if (event == null) return;

    final stageActions = projectActions
        .where((action) => action.stageId == stageId)
        .toList();
    if (stageActions.isEmpty) return;

    final allCompleted = stageActions.every((action) => action.isCompleted);
    final anyCompleted = stageActions.any((action) => action.isCompleted);

    final newStatus = allCompleted
        ? 'completed'
        : (anyCompleted || event.status == 'current')
        ? 'current'
        : 'upcoming';

    if (newStatus == event.status) return;

    await updateEvent(event.copyWith(status: newStatus));
  }

  Future<void> _syncToClient(TimelineEventModel event) async {
    if (event.professionalUid.isEmpty || event.projectId.isEmpty) return;
    await ref
        .read(clientPortalServiceProvider)
        .syncTimelineEventForClientAccounts(event: event);
  }

  Future<void> _syncProjectFromTimeline(
    String projectId, {
    List<TimelineEventModel>? events,
  }) async {
    // Single source of truth: recomputes project.progress/status from every
    // contributing structure (timeline + actions + tasks), not just this
    // controller's own events — see syncProjectProgress.
    await syncProjectProgress(ref, projectId, events: events);
  }
}

int _sortEvents(TimelineEventModel a, TimelineEventModel b) {
  return a.order.compareTo(b.order);
}
