import 'package:clientflow_pro/core/widgets/app_empty_state.dart';
import 'package:clientflow_pro/data/models/task_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../data/models/project_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../data/services/project_pdf_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/project_providers.dart';

import '../../tasks/providers/task_providers.dart';

class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectByIdProvider(projectId));
    final projectTasks = ref.watch(tasksByProjectProvider(projectId));

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: project == null
            ? const Center(child: Text('Projet introuvable'))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProjectHeader(
                      project: project,
                      onEdit: () => context.push('/projects/${project.id}/edit'),
                      onDelete: () => _confirmDeleteProject(context, ref, project),
                    ),
                    const SizedBox(height: 24),
                    _ProjectHeroCard(
                      project: project,
                      percent: (project.progress * 100).round(),
                    ),
                    const SizedBox(height: 14),
                    _ExportPdfButton(
                      onTap: () => _exportPdf(context, project, projectTasks),
                    ),
                    const SizedBox(height: 14),
                    _ClientPortalCard(project: project, tasks: projectTasks),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: 'Informations projet'),
                    const SizedBox(height: 14),
                    _ProjectInfoCard(project: project),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: 'Tâches associées'),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        context.push(
                          '/tasks/add?projectId=${project.id}&projectName=${Uri.encodeComponent(project.title)}',
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Ajouter une tâche',
                            style: TextStyle(
                              color: AppTheme.cardColor(context),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    projectTasks.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.task_alt_rounded,
                            title: 'Aucune tâche',
                            description:
                                'Ajoutez votre première tâche pour ce projet.',
                          )
                        : Column(
                            children: projectTasks
                                .map(
                                  (task) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _ProjectTaskCard(task: task),
                                  ),
                                )
                                .toList(),
                          ),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: 'Timeline'),
                    const SizedBox(height: 14),
                    const _TimelineCard(),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: 'Notes projet'),
                    const SizedBox(height: 14),
                    _ProjectNotesCard(project: project),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProjectTaskCard extends ConsumerWidget {
  const _ProjectTaskCard({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = task.status == 'Terminé';

    return GestureDetector(
      onTap: () {
        ref.read(taskControllerProvider.notifier).toggleTaskStatus(task);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isDone ? const Color(0xFF16A34A) : AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(
              task.deadline,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryTextColor(context),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => context.push('/tasks/${task.id}'),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.secondaryTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _exportPdf(
  BuildContext context,
  ProjectModel project,
  List<TaskModel> tasks,
) async {
  try {
    await ProjectPdfService.shareProjectReport(project: project, tasks: tasks);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossible de générer le PDF pour le moment.')),
    );
  }
}

Future<void> _confirmDeleteProject(
  BuildContext context,
  WidgetRef ref,
  ProjectModel project,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer ce projet ?'),
      content: Text(
        'Cette action supprimera définitivement "${project.title}". Elle est irréversible.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Supprimer',
            style: TextStyle(color: Color(0xFFDC2626)),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  await ref.read(projectControllerProvider.notifier).deleteProject(project.id);

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Projet supprimé.')),
  );

  context.pop();
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.project,
    required this.onEdit,
    required this.onDelete,
  });

  final ProjectModel project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                'Détail projet',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                project.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onDelete,
          child: Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFDC2626),
              size: 21,
            ),
          ),
        ),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.edit_rounded, color: AppTheme.cardColor(context), size: 21),
          ),
        ),
      ],
    );
  }
}

class _ProjectHeroCard extends StatelessWidget {
  const _ProjectHeroCard({required this.project, required this.percent});

  final ProjectModel project;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBadge(status: project.status),
          const SizedBox(height: 18),
          Text(
            project.title,
            style: TextStyle(
              color: AppTheme.cardColor(context),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${project.clientName} • ${project.type}',
            style: TextStyle(
              color: AppTheme.cardColor(context).withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: LinearProgressIndicator(
                    value: project.progress,
                    minHeight: 10,
                    backgroundColor: AppTheme.cardColor(context).withValues(alpha: 0.22),
                    color: AppTheme.cardColor(context),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '$percent%',
                style: TextStyle(
                  color: AppTheme.cardColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportPdfButton extends StatelessWidget {
  const _ExportPdfButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'Exporter en PDF',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientPortalCard extends ConsumerWidget {
  const _ClientPortalCard({required this.project, required this.tasks});

  final ProjectModel project;
  final List<TaskModel> tasks;

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    try {
      final token = await ref.read(sharedProjectServiceProvider).publish(
            ownerUid: uid,
            project: project,
            tasks: tasks,
          );

      await ref
          .read(projectControllerProvider.notifier)
          .updateProject(project.copyWith(shareToken: token));

      if (!context.mounted) return;
      _showCodeDialog(context, token);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de créer l\'accès client pour le moment.')),
      );
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(sharedProjectServiceProvider).revoke(project.shareToken);

      await ref
          .read(projectControllerProvider.notifier)
          .updateProject(project.copyWith(shareToken: ''));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accès client révoqué.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de révoquer l\'accès pour le moment.')),
      );
    }
  }

  void _showCodeDialog(BuildContext context, String token) {
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                token,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isShared = project.isShared;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt_rounded, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Espace client',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppTheme.mainTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isShared
                ? 'Votre client peut suivre ce projet avec le code ${project.shareToken}.'
                : 'Générez un code pour que votre client suive l\'avancement sans créer de compte.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.secondaryTextColor(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          if (isShared)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: project.shareToken));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copié.')),
                      );
                    },
                    child: const Text('Copier le code'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () => _revoke(context, ref),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                    child: const Text('Révoquer'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _publish(context, ref),
                child: const Text('Créer un accès client'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectInfoCard extends StatelessWidget {
  const _ProjectInfoCard({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_rounded,
            label: 'Client',
            value: project.clientName,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.category_rounded,
            label: 'Type',
            value: project.type,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.payments_rounded,
            label: 'Budget',
            value: project.budget,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.event_rounded,
            label: 'Deadline',
            value: project.deadline,
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard();

  @override
  Widget build(BuildContext context) {
    final items = const [
      _TimelineItem(title: 'Brief client reçu', date: '12 avril 2026'),
      _TimelineItem(title: 'Maquette homepage validée', date: '16 avril 2026'),
      _TimelineItem(title: 'Développement WooCommerce', date: 'En cours'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _TimelineRow(item: item),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});

  final _TimelineItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            item.title,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          item.date,
          style: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProjectNotesCard extends ConsumerWidget {
  const _ProjectNotesCard({required this.project});

  final ProjectModel project;

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: project.notes);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Note projet'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Ajoutez une note sur ce projet...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result == null) return;

    await ref
        .read(projectControllerProvider.notifier)
        .updateProject(project.copyWith(notes: result));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNotes = project.notes.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _editNotes(context, ref),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Text(
            hasNotes ? project.notes : 'Aucune note pour ce projet. Touchez pour en ajouter une.',
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.secondaryTextColor(context), size: 20),
        const SizedBox(width: 12),
        Text(
          '$label : ',
          style: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: AppTheme.cardColor(context),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFE2E8F0)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.025),
        blurRadius: 14,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class _TimelineItem {
  const _TimelineItem({required this.title, required this.date});

  final String title;
  final String date;
}
