import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification_model.dart';

class AppNotificationRepository {
  const AppNotificationRepository({
    required this.firestore,
    required this.auth,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  Stream<List<AppNotificationModel>> watchCurrentUserNotifications() {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map(
                (doc) => AppNotificationModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList();
          notifications.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return notifications;
        });
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;

    await firestore.collection('notifications').doc(notificationId).set({
      'read': true,
    }, SetOptions(merge: true));
  }

  Future<void> markAllAsRead(List<AppNotificationModel> notifications) async {
    final unread = notifications.where((notification) => !notification.read);
    final batch = firestore.batch();

    for (final notification in unread) {
      batch.set(firestore.collection('notifications').doc(notification.id), {
        'read': true,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
