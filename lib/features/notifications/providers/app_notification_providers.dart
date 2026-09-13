import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_notification_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/repositories/app_notification_repository.dart';
import '../../auth/providers/auth_providers.dart';

final appNotificationRepositoryProvider = Provider<AppNotificationRepository>((
  ref,
) {
  return AppNotificationRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final appNotificationsProvider = StreamProvider<List<AppNotificationModel>>((
  ref,
) {
  return ref
      .watch(appNotificationRepositoryProvider)
      .watchCurrentUserNotifications();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(appNotificationsProvider).value;
  if (notifications == null) return 0;
  return notifications.where((notification) => !notification.read).length;
});
