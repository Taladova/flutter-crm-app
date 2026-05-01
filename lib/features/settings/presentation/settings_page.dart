import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../app/theme_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../clients/providers/client_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../../tasks/providers/task_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;
    final userEmail = currentUser?.email ?? 'Compte inconnu';

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SettingsHeader(),
              const SizedBox(height: 24),
              _ProfileCard(email: userEmail),
              const SizedBox(height: 24),
              Text(
                'Préférences',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                children: [
                  Consumer(
                    builder: (context, ref, child) {
                      final themeModeAsync = ref.watch(themeModeProvider);
                      final themeMode = themeModeAsync.value ?? ThemeMode.light;
                      final isDark = themeMode == ThemeMode.dark;

                      return _SettingsTile(
                        icon: Icons.dark_mode_rounded,
                        title: 'Mode sombre',
                        subtitle: isDark ? 'Activé' : 'Désactivé',
                        trailing: Switch(
                          value: isDark,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (value) {
                            ref
                                .read(themeModeProvider.notifier)
                                .toggleTheme(value);
                          },
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    subtitle: 'Rappels de deadlines',
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppTheme.secondaryTextColor(context),
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppTheme.cardColor(context),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (_) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.notifications_active_rounded,
                                  size: 46,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Notifications bientôt disponibles',
                                  style: TextStyle(
                                    color: AppTheme.mainTextColor(context),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Vous recevrez bientôt des rappels pour vos tâches et projets.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.secondaryTextColor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Application',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                children: [
                  const _SettingsTile(
                    icon: Icons.cloud_sync_rounded,
                    title: 'Synchronisation cloud',
                    subtitle: 'Préparé pour Firebase',
                    trailing: _ComingSoonBadge(),
                  ),
                  const _SettingsTile(
                    icon: Icons.people_alt_rounded,
                    title: 'Espace client',
                    subtitle: 'Accès client au suivi projet',
                    trailing: _ComingSoonBadge(),
                  ),
                  const _SettingsTile(
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'Export PDF',
                    subtitle: 'Devis, avancement et rapport projet',
                    trailing: _ComingSoonBadge(),
                  ),
                  _SettingsTile(
                    icon: Icons.restart_alt_rounded,
                    title: 'Réinitialiser la démo',
                    subtitle: 'Restaurer les données de départ',
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppTheme.secondaryTextColor(context),
                    ),
                    onTap: () async {
                      await ref
                          .read(clientControllerProvider.notifier)
                          .resetClients();
                      await ref
                          .read(projectControllerProvider.notifier)
                          .resetProjects();
                      await ref
                          .read(taskControllerProvider.notifier)
                          .resetTasks();

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Données de démo réinitialisées.'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Compte', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _LogoutButton(
                onTap: () async {
                  await ref.read(authServiceProvider).logout();

                  ref.invalidate(clientControllerProvider);
                  ref.invalidate(projectControllerProvider);
                  ref.invalidate(taskControllerProvider);

                  if (!context.mounted) return;
                  context.go('/login');
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'ClientFlow Pro • Version 1.0.0',
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsHeader extends ConsumerWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configuration',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Paramètres',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          color: AppTheme.cardColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (value) async {
            if (value == 'logout') {
              await ref.read(authServiceProvider).logout();

              ref.invalidate(clientControllerProvider);
              ref.invalidate(projectControllerProvider);
              ref.invalidate(taskControllerProvider);
              ref.invalidate(themeModeProvider);

              if (!context.mounted) return;

              context.go('/login');
            }

            if (value == 'about') {
              showAboutDialog(
                context: context,
                applicationName: 'ClientFlow Pro',
                applicationVersion: '1.0.0',
              );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'about',
              child: Text(
                'À propos',
                style: TextStyle(
                  color: AppTheme.mainTextColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Text(
                'Déconnexion',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Icon(
              Icons.settings_rounded,
              color: AppTheme.mainTextColor(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          if (!AppTheme.isDark(context))
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.22),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Compte connecté',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'Compte démo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: children
            .asMap()
            .entries
            .map(
              (entry) => Column(
                children: [
                  entry.value,
                  if (entry.key != children.length - 1)
                    Divider(
                      height: 1,
                      color: AppTheme.borderColor(context).withOpacity(0.45),
                    ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Text(
        'Bientôt',
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = AppTheme.isDark(context)
        ? const Color(0xFF7F1D1D).withOpacity(0.45)
        : const Color(0xFFFEE2E2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
        ),
        child: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 12),
            Text(
              'Se déconnecter',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
