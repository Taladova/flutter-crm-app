import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../data/models/project_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/services/project_pdf_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/project_providers.dart';
import '../../tasks/providers/task_providers.dart';

class ClientSpacePage extends ConsumerWidget {
  const ClientSpacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(onBack: () => context.pop()),
              const SizedBox(height: 8),
              Expanded(
                child: projectsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Center(
                    child: AppEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Erreur',
                      description: 'Impossible de charger vos projets.',
                      onRetry: () => ref.invalidate(projectControllerProvider),
                    ),
                  ),
                  data: (projects) {
                    if (projects.isEmpty) {
                      return Center(
                        child: AppEmptyState(
                          icon: Icons.people_alt_rounded,
                          title: 'Aucun projet',
                          description:
                              'Créez un projet pour donner à vos clients un accès de suivi ou exporter un rapport PDF.',
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(top: 8, bottom: 32),
                      itemCount: projects.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) =>
                          _ProjectPortalCard(project: projects[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.mainTextColor(context),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Espace client',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Partage & rapports',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectPortalCard extends ConsumerStatefulWidget {
  const _ProjectPortalCard({required this.project});

  final ProjectModel project;

  @override
  ConsumerState<_ProjectPortalCard> createState() => _ProjectPortalCardState();
}

class _ProjectPortalCardState extends ConsumerState<_ProjectPortalCard> {
  bool isBusy = false;

  Future<void> _publish() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    final tasks = ref.read(tasksByProjectProvider(widget.project.id));

    setState(() => isBusy = true);

    try {
      final token = await ref
          .read(sharedProjectServiceProvider)
          .publish(ownerUid: uid, project: widget.project, tasks: tasks);

      await ref
          .read(projectControllerProvider.notifier)
          .updateProject(widget.project.copyWith(shareToken: token));

      if (!mounted) return;
      _showCodeDialog(token);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Impossible de créer l\'accès client pour le moment.');
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> _revoke() async {
    setState(() => isBusy = true);

    try {
      await ref
          .read(sharedProjectServiceProvider)
          .revoke(widget.project.shareToken);

      await ref
          .read(projectControllerProvider.notifier)
          .updateProject(widget.project.copyWith(shareToken: ''));

      if (!mounted) return;
      _showMessage('Accès client révoqué.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Impossible de révoquer l\'accès pour le moment.');
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> _exportPdf() async {
    final tasks = ref.read(tasksByProjectProvider(widget.project.id));

    setState(() => isBusy = true);

    try {
      await ProjectPdfService.shareProjectReport(
        project: widget.project,
        tasks: tasks,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Impossible de générer le PDF pour le moment.');
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCodeDialog(String token) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accès client créé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Communiquez ce code à votre client. Depuis l\'app Deskly, il pourra '
              'suivre l\'avancement de ce projet sans créer de compte.',
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.secondarySurface(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                token,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Copier le code'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final isShared = project.isShared;
    final percent = (project.progress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          if (!AppTheme.isDark(context))
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.language_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${project.clientName} · $percent%',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusBadge(status: project.status),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: project.progress,
              minHeight: 7,
              backgroundColor: AppTheme.borderColor(
                context,
              ).withValues(alpha: 0.65),
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isShared
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : AppTheme.secondaryTextColor(
                      context,
                    ).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isShared
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : AppTheme.borderColor(context),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isShared
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: isShared
                      ? AppTheme.primaryColor
                      : AppTheme.secondaryTextColor(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isShared
                            ? 'Accès client actif'
                            : 'Accès client inactif',
                        style: TextStyle(
                          color: isShared
                              ? AppTheme.primaryColor
                              : AppTheme.mainTextColor(context),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isShared
                            ? 'Code ${project.shareToken}'
                            : 'Créez un code de suivi pour ce projet.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isShared)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PortalActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copier',
                  onTap: isBusy ? null : _copyCode,
                ),
                _PortalActionButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'PDF',
                  onTap: isBusy ? null : _exportPdf,
                ),
                _PortalActionButton(
                  icon: Icons.link_off_rounded,
                  label: 'Révoquer',
                  destructive: true,
                  onTap: isBusy ? null : _revoke,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : _publish,
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('Créer un accès'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  onPressed: isBusy ? null : _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: 'Exporter en PDF',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.project.shareToken));
    if (!mounted) return;
    _showMessage('Code copié.');
  }
}

class _PortalActionButton extends StatelessWidget {
  const _PortalActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFDC2626) : AppTheme.primaryColor;

    return SizedBox(
      width: 118,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color: destructive
                ? color.withValues(alpha: 0.25)
                : AppTheme.borderColor(context),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
