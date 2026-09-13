import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../features/auth/providers/auth_providers.dart';
import 'deskly_logo.dart';

/// Deskly's secondary navigation drawer. One shared instance, opened from a
/// hamburger button on the main tabs — never duplicated per page. Only holds
/// functions that don't already live in the bottom navigation.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.userName, required this.userEmail});

  final String userName;
  final String userEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width * 0.84;

    return Drawer(
      width: width,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                children: [
                  const DesklyLogo(size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.mainTextColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          userEmail,
                          maxLines: 1,
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
                ],
              ),
            ),
            Divider(height: 1, color: AppTheme.borderColor(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                children: [
                  DrawerItem(
                    icon: Icons.groups_outlined,
                    title: 'Espaces clients',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/client-spaces');
                    },
                  ),
                  DrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Réglages',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: DrawerItem(
                icon: Icons.logout_rounded,
                title: 'Déconnexion',
                isDestructive: true,
                onTap: () => _confirmLogout(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez vous reconnecter pour accéder à votre espace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Se déconnecter',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (context.mounted) Navigator.pop(context);
    await ref.read(authServiceProvider).logout();
    if (!context.mounted) return;
    context.go('/login');
  }
}

/// Small uppercase group title used inside [AppDrawer].
class DrawerSection extends StatelessWidget {
  const DrawerSection(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.secondaryTextColor(context),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// One tappable row inside [AppDrawer], with an optional count badge and a
/// subtle selected state for the entry matching the current page.
class DrawerItem extends StatelessWidget {
  const DrawerItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
    this.isDestructive = false,
    this.isSelected = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? badge;
  final bool isDestructive;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppTheme.errorColor
        : isSelected
        ? AppTheme.primary(context)
        : AppTheme.mainTextColor(context);

    return ListTile(
      dense: true,
      minLeadingWidth: 24,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: isSelected
          ? AppTheme.primary(context).withValues(alpha: 0.08)
          : null,
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      trailing: badge == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  color: AppTheme.primary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
      onTap: onTap,
    );
  }
}
