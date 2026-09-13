import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_notification_model.dart';
import '../../../data/models/client_account_model.dart';
import '../../../data/models/client_action_model.dart';
import '../../../data/models/client_document_model.dart';
import '../../../data/models/client_message_model.dart';
import '../../../data/models/deliverable_annotation_model.dart';
import '../../../data/models/deliverable_model.dart';
import '../../../data/models/deliverable_version_model.dart';
import '../../../data/models/document_request_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/timeline_event_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/services/client_portal_service.dart';
import '../../auth/providers/auth_providers.dart';

final clientPortalServiceProvider = Provider<ClientPortalService>((ref) {
  return ClientPortalService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    storage: ref.watch(firebaseStorageProvider),
  );
});

final clientAccountProvider = FutureProvider<ClientAccountModel?>((ref) {
  return ref.watch(clientPortalServiceProvider).currentClientAccount();
});

final clientHomeAccountProvider = FutureProvider<ClientAccountModel?>((ref) {
  final service = ref.watch(clientPortalServiceProvider);

  // Temporary diagnostic: should start once on the client Home page, then only
  // after login/logout or an explicit refresh.
  // ignore: avoid_print
  print('[client-home] account provider started');

  return service.currentClientAccount(debugLog: false);
});

/// The display name of the professional a client account is linked to,
/// resolved from `professionalId` (see clientAccountProvider).
final clientPortalProfessionalNameProvider =
    FutureProvider.family<String?, String>((ref, professionalId) {
      return ref
          .watch(clientPortalServiceProvider)
          .fetchProfessionalName(professionalId);
    });

final clientPortalProjectsProvider = StreamProvider<List<ProjectModel>>((ref) {
  return ref.watch(clientPortalServiceProvider).currentClientProjectsStream();
});

final clientHomeProjectsProvider = StreamProvider<List<ProjectModel>>((
  ref,
) async* {
  final service = ref.watch(clientPortalServiceProvider);
  final account = await ref.read(clientHomeAccountProvider.future);
  if (account == null) {
    yield const <ProjectModel>[];
    return;
  }

  // Temporary diagnostic: this should print once when the Home stream starts,
  // then only again after refresh/login changes.
  // ignore: avoid_print
  print('[client-home] projects provider started uid=${account.uid}');

  yield* service.clientProjectsStreamForAccount(account);
});

final clientPortalMessagesProvider = StreamProvider<List<ClientMessageModel>>((
  ref,
) {
  return ref.watch(clientPortalServiceProvider).clientMessagesStream();
});

final clientPortalDocumentsProvider = StreamProvider<List<ClientDocumentModel>>(
  (ref) {
    return ref.watch(clientPortalServiceProvider).documentsStream();
  },
);

final clientPortalDocumentRequestsProvider =
    StreamProvider<List<DocumentRequestModel>>((ref) {
      return ref.watch(clientPortalServiceProvider).documentRequestsStream();
    });

/// Validations (deliverables) for the projects clientHomeProjectsProvider has
/// already resolved as accessible — the same shared project provider used by
/// Accueil/Avancement/Profil — instead of an independent account/project
/// lookup, so this list never drifts out of sync with what those pages show.
final clientPortalDeliverablesProvider = StreamProvider<List<DeliverableModel>>(
  (ref) async* {
    final service = ref.watch(clientPortalServiceProvider);
    final account = await ref.read(clientHomeAccountProvider.future);
    if (account == null) {
      yield const <DeliverableModel>[];
      return;
    }

    final projects = await ref.watch(clientHomeProjectsProvider.future);
    yield* service.deliverablesStreamForProjects(
      professionalId: account.professionalId,
      clientId: account.clientId,
      sharedClientId: account.sharedClientId,
      projectIds: projects.map((project) => project.id).toList(),
    );
  },
);

final clientPortalDeliverableVersionsProvider =
    StreamProvider<List<DeliverableVersionModel>>((ref) async* {
      final service = ref.watch(clientPortalServiceProvider);
      final account = await ref.read(clientHomeAccountProvider.future);
      if (account == null) {
        yield const <DeliverableVersionModel>[];
        return;
      }

      final projects = await ref.watch(clientHomeProjectsProvider.future);
      yield* service.deliverableVersionsStreamForProjects(
        professionalId: account.professionalId,
        clientId: account.clientId,
        sharedClientId: account.sharedClientId,
        projectIds: projects.map((project) => project.id).toList(),
      );
    });

final clientProjectDeliverablesProvider =
    StreamProvider.family<List<DeliverableModel>, String>((
      ref,
      projectId,
    ) async* {
      final cleanProjectId = projectId.trim();
      if (cleanProjectId.isEmpty) {
        yield const <DeliverableModel>[];
        return;
      }

      final service = ref.watch(clientPortalServiceProvider);
      final account = await ref.read(clientHomeAccountProvider.future);
      if (account == null) {
        yield const <DeliverableModel>[];
        return;
      }

      yield* service.deliverablesStreamForProjects(
        professionalId: account.professionalId,
        clientId: account.clientId,
        sharedClientId: account.sharedClientId,
        projectIds: [cleanProjectId],
      );
    });

final clientProjectDeliverableVersionsProvider =
    StreamProvider.family<List<DeliverableVersionModel>, String>((
      ref,
      projectId,
    ) async* {
      final cleanProjectId = projectId.trim();
      if (cleanProjectId.isEmpty) {
        yield const <DeliverableVersionModel>[];
        return;
      }

      final service = ref.watch(clientPortalServiceProvider);
      final account = await ref.read(clientHomeAccountProvider.future);
      if (account == null) {
        yield const <DeliverableVersionModel>[];
        return;
      }

      yield* service.deliverableVersionsStreamForProjects(
        professionalId: account.professionalId,
        clientId: account.clientId,
        sharedClientId: account.sharedClientId,
        projectIds: [cleanProjectId],
      );
    });

final clientPortalDeliverableAnnotationsProvider =
    StreamProvider<List<DeliverableAnnotationModel>>((ref) {
      return ref
          .watch(clientPortalServiceProvider)
          .deliverableAnnotationsStream();
    });

final clientPortalActionsProvider = StreamProvider<List<ClientActionModel>>((
  ref,
) {
  return ref.watch(clientPortalServiceProvider).actionsStream();
});

final clientHomeActionsProvider = StreamProvider<List<ClientActionModel>>((
  ref,
) async* {
  final service = ref.watch(clientPortalServiceProvider);
  final account = await ref.read(clientHomeAccountProvider.future);
  if (account == null) {
    yield const <ClientActionModel>[];
    return;
  }

  // Temporary diagnostic: this should not restart continuously while staying
  // on the client Home page.
  // ignore: avoid_print
  print('[client-home] actions provider started uid=${account.uid}');

  yield* service.actionsStreamForAccount(account);
});

final clientProgressProjectsProvider = StreamProvider<List<ProjectModel>>((
  ref,
) async* {
  final service = ref.watch(clientPortalServiceProvider);
  final account = await ref.read(clientHomeAccountProvider.future);
  if (account == null) {
    yield const <ProjectModel>[];
    return;
  }

  // ignore: avoid_print
  print('[client-progress] projects provider started uid=${account.uid}');

  yield* service.clientProjectsStreamForAccount(account);
});

final clientProgressActionsProvider = StreamProvider<List<ClientActionModel>>((
  ref,
) async* {
  final service = ref.watch(clientPortalServiceProvider);
  final account = await ref.read(clientHomeAccountProvider.future);
  if (account == null) {
    yield const <ClientActionModel>[];
    return;
  }

  // ignore: avoid_print
  print('[client-progress] actions provider started uid=${account.uid}');

  yield* service.actionsStreamForAccount(account);
});

final clientPortalTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  return ref.watch(clientPortalServiceProvider).tasksStream();
});

final clientProgressTasksProvider = StreamProvider<List<TaskModel>>((
  ref,
) async* {
  final service = ref.watch(clientPortalServiceProvider);
  final account = await ref.read(clientHomeAccountProvider.future);
  if (account == null) {
    yield const <TaskModel>[];
    return;
  }

  // ignore: avoid_print
  print('[client-progress] tasks provider started uid=${account.uid}');

  yield* service.tasksStreamForAccount(account);
});

final clientPortalTimelineProvider =
    StreamProvider.family<List<TimelineEventModel>, String>((ref, projectId) {
      return ref.watch(clientPortalServiceProvider).timelineStream(projectId);
    });

final clientPortalNotificationsProvider =
    StreamProvider<List<AppNotificationModel>>((ref) {
      return ref.watch(clientPortalServiceProvider).notificationsStream();
    });
