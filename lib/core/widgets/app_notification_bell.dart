import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_role_theme.dart';
import '../../app/app_theme.dart';
import '../../data/models/app_notification_model.dart';
import '../../features/notifications/providers/app_notification_providers.dart';
import 'app_empty_state.dart';
import 'app_header_icon_button.dart';

class AppNotificationBell extends ConsumerWidget {
  const AppNotificationBell({super.key, required this.portal});

  final NotificationPortal portal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppHeaderIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onTap: () => _showNotifications(context, ref),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.cardColor(context),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotifications(BuildContext context, WidgetRef ref) {
    final rootRouter = GoRouter.of(context);
    // Bottom sheets are pushed onto the Navigator's shared Overlay, which
    // sits above (not inside) whichever page-level role Theme is active —
    // so it must be re-applied explicitly here, keyed off `portal` (this
    // widget already knows which side it's on) rather than assumed from
    // ambient context.
    final roleTheme = portal == NotificationPortal.client
        ? AppRoleTheme.client
        : AppRoleTheme.professional;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Theme(
          data: roleTheme.themeData,
          child: Consumer(
            builder: (context, ref, _) {
              final notificationsAsync = ref.watch(appNotificationsProvider);

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: notificationsAsync.when(
                    loading: () => const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const AppEmptyState(
                      icon: Icons.notifications_off_outlined,
                      title: 'Notifications indisponibles',
                      description: 'Impossible de charger vos notifications.',
                    ),
                    data: (notifications) {
                      final visible = notifications.take(20).toList();

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.borderColor(sheetContext),
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Notifications',
                                  style: Theme.of(
                                    sheetContext,
                                  ).textTheme.titleLarge,
                                ),
                              ),
                              if (notifications.any(
                                (notification) => !notification.read,
                              ))
                                TextButton(
                                  onPressed: () => ref
                                      .read(appNotificationRepositoryProvider)
                                      .markAllAsRead(notifications),
                                  child: const Text('Tout lire'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (visible.isEmpty)
                            const AppEmptyState(
                              icon: Icons.notifications_none_rounded,
                              title: 'Aucune notification',
                              description:
                                  'Les événements importants apparaîtront ici.',
                            )
                          else
                            Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final notification = visible[index];
                                  return _NotificationRow(
                                    notification: notification,
                                    onTap: () {
                                      final destination = _notificationPath(
                                        notification,
                                      );
                                      unawaited(
                                        ref
                                            .read(
                                              appNotificationRepositoryProvider,
                                            )
                                            .markAsRead(notification.id),
                                      );
                                      if (!sheetContext.mounted) return;
                                      Navigator.pop(sheetContext);
                                      rootRouter.go(destination);
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _notificationPath(AppNotificationModel notification) {
    final projectPath = notification.projectId.isEmpty
        ? null
        : portal == NotificationPortal.client
        ? '/client/projects/${Uri.encodeComponent(notification.projectId)}'
        : '/projects/${Uri.encodeComponent(notification.projectId)}';

    switch (notification.type) {
      case 'message_client':
        return '/messages';
      case 'message_professional':
        return '/client/messages';
      case 'document_received':
      case 'validation_approved':
      case 'changes_requested':
      case 'project_updated':
        return projectPath ??
            (portal == NotificationPortal.client ? '/client/home' : '/main');
      case 'document_requested':
        return '/client/documents';
      case 'validation_requested':
        return projectPath == null
            ? '/client/home'
            : '$projectPath?tab=validations';
      case 'client_action':
        return projectPath ?? '/client/home';
      default:
        return portal == NotificationPortal.client ? '/client/home' : '/main';
    }
  }
}

enum NotificationPortal { professional, client }

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _notificationColor(notification.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: notification.read
                  ? AppTheme.secondarySurface(context)
                  : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: notification.read
                    ? AppTheme.borderColor(context)
                    : color.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _notificationIcon(notification.type),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          color: AppTheme.mainTextColor(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _relativeNotificationTime(notification.createdAt),
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _notificationIcon(String type) {
  switch (type) {
    case 'message_client':
    case 'message_professional':
      return Icons.chat_bubble_rounded;
    case 'document_received':
    case 'document_requested':
      return Icons.folder_rounded;
    case 'validation_approved':
    case 'validation_requested':
      return Icons.verified_rounded;
    case 'changes_requested':
      return Icons.edit_note_rounded;
    case 'project_updated':
      return Icons.work_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

Color _notificationColor(String type) {
  switch (type) {
    case 'changes_requested':
      return const Color(0xFFF59E0B);
    case 'validation_approved':
    case 'document_received':
      return const Color(0xFF16A34A);
    case 'document_requested':
    case 'validation_requested':
    case 'client_action':
      return AppTheme.primaryColor;
    default:
      return const Color(0xFF64748B);
  }
}

String _relativeNotificationTime(DateTime? date) {
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'maintenant';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  return '${diff.inDays} j';
}
