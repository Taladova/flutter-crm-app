import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../app/theme_provider.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../clients/providers/client_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../providers/notifications_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;
    final userEmail = currentUser?.email ?? 'Compte inconnu';
    final userName = ref.watch(userDisplayNameProvider).value ?? 'Utilisateur';

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
              _ProfileCard(
                name: userName,
                email: userEmail,
                onEditName: () => _editDisplayName(context, ref, userName),
              ),
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
                          activeThumbColor: AppTheme.primaryColor,
                          onChanged: (value) {
                            ref
                                .read(themeModeProvider.notifier)
                                .toggleTheme(value);
                          },
                        ),
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final notificationsAsync = ref.watch(
                        notificationsEnabledProvider,
                      );
                      final enabled = notificationsAsync.value ?? true;

                      return _SettingsTile(
                        icon: Icons.notifications_rounded,
                        title: 'Notifications',
                        subtitle: enabled
                            ? 'Rappels d’échéances activés'
                            : 'Rappels d’échéances désactivés',
                        trailing: Switch(
                          value: enabled,
                          activeThumbColor: AppTheme.primaryColor,
                          onChanged: (value) {
                            ref
                                .read(notificationsEnabledProvider.notifier)
                                .setEnabled(value);
                          },
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    title: 'Langue',
                    subtitle: 'Français',
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Langue'),
                          content: const Text(
                            'Deskly est disponible en français pour le moment. '
                            'D\'autres langues seront ajoutées prochainement.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
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
                    subtitle: 'Vos données sont sauvegardées en temps réel',
                    trailing: _ActiveBadge(),
                  ),
                  _SettingsTile(
                    icon: Icons.people_alt_rounded,
                    title: 'Espace client',
                    subtitle: 'Accès de suivi et export PDF par projet',
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppTheme.secondaryTextColor(context),
                    ),
                    onTap: () => context.push('/client-space'),
                  ),
                  _SettingsTile(
                    icon: Icons.delete_sweep_rounded,
                    title: 'Supprimer toutes mes données',
                    subtitle:
                        'Efface définitivement clients, projets et tâches',
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Supprimer toutes les données ?'),
                          content: const Text(
                            'Tous vos clients, projets et tâches seront définitivement '
                            'supprimés. Cette action est irréversible.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text(
                                'Tout supprimer',
                                style: TextStyle(color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;

                      await ref
                          .read(clientControllerProvider.notifier)
                          .clearClients();
                      await ref
                          .read(projectControllerProvider.notifier)
                          .clearProjects();
                      await ref
                          .read(taskControllerProvider.notifier)
                          .clearTasks();

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Toutes vos données ont été supprimées.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Légal', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _SettingsSection(
                children: [
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Confidentialité & mentions légales',
                    subtitle: 'Données collectées, sécurité, vos droits',
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppTheme.secondaryTextColor(context),
                    ),
                    onTap: () => context.push('/legal'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Compte', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _LogoutButton(onTap: () => _logout(context, ref)),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Deskly • Version 1.0.0',
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

Future<void> _editDisplayName(
  BuildContext context,
  WidgetRef ref,
  String currentName,
) async {
  final controller = TextEditingController(
    text: currentName == 'Utilisateur' ? '' : currentName,
  );

  final newName = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Votre nom'),
      content: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nom',
          hintText: 'Ex : Marie Dupont',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );

  if (newName == null || newName.isEmpty) return;

  final user = ref.read(firebaseAuthProvider).currentUser;
  if (user == null) return;

  await user.updateDisplayName(newName);
  await user.reload();

  await ref.read(firestoreProvider).collection('users').doc(user.uid).set({
    'name': newName,
  }, SetOptions(merge: true));

  ref.invalidate(userDisplayNameProvider);
}

class _SettingsHeader extends ConsumerWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _HeaderIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => context.go('/main?tab=0'),
        ),
        const SizedBox(width: 12),
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
        _HeaderIconButton(
          icon: Icons.more_horiz_rounded,
          onTap: () => _openQuickMenu(context, ref),
          isPrimary: true,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final color = isPrimary
        ? AppTheme.primaryColor
        : AppTheme.mainTextColor(context);

    return Material(
      color: isPrimary
          ? AppTheme.primaryColor.withValues(alpha: 0.12)
          : AppTheme.cardColor(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? AppTheme.primaryColor.withValues(alpha: 0.14)
                  : AppTheme.borderColor(context),
            ),
          ),
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}

Future<void> _logout(BuildContext context, WidgetRef ref) async {
  await ref.read(authServiceProvider).logout();

  ref.invalidate(clientControllerProvider);
  ref.invalidate(projectControllerProvider);
  ref.invalidate(taskControllerProvider);
  ref.invalidate(themeModeProvider);

  if (!context.mounted) return;

  context.go('/login');
}

Future<void> _openQuickMenu(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.cardColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor(context),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 18),
              _QuickMenuTile(
                icon: Icons.info_outline_rounded,
                title: 'À propos',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showAboutDialog(
                    context: context,
                    applicationName: 'Deskly',
                    applicationVersion: '1.0.0',
                  );
                },
              ),
              _QuickMenuTile(
                icon: Icons.logout_rounded,
                title: 'Déconnexion',
                danger: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _logout(context, ref);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _QuickMenuTile extends StatelessWidget {
  const _QuickMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFDC2626)
        : AppTheme.mainTextColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      (danger ? const Color(0xFFDC2626) : AppTheme.primaryColor)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: danger
                      ? const Color(0xFFDC2626)
                      : AppTheme.primaryColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.onEditName,
  });

  final String name;
  final String email;
  final VoidCallback onEditName;

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
              color: AppTheme.primaryColor.withValues(alpha: 0.22),
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
              color: Colors.black.withValues(alpha: 0.12),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onEditName,
                      child: Icon(
                        Icons.edit_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
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
                    color: Colors.black.withValues(alpha: 0.12),
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
                      color: AppTheme.borderColor(
                        context,
                      ).withValues(alpha: 0.45),
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
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

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Text(
        'Actif',
        style: TextStyle(
          color: Color(0xFF16A34A),
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
        ? const Color(0xFF7F1D1D).withValues(alpha: 0.45)
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
