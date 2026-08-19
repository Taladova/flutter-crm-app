import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../data/models/client_model.dart';
import '../providers/client_providers.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../projects/providers/project_providers.dart';
import '../../../data/models/project_model.dart';

class ClientDetailPage extends ConsumerWidget {
  const ClientDetailPage({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientByIdProvider(clientId));
    final projectsAsync = ref.watch(projectControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: client == null
            ? const Center(child: Text('Client introuvable'))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailHeader(
                      client: client,
                      onEdit: () => context.push('/clients/${client.id}/edit'),
                      onDelete: () => _confirmDelete(context, ref, client),
                    ),
                    const SizedBox(height: 24),
                    _ClientInfoCard(client: client),
                    const SizedBox(height: 24),
                    _QuickActions(client: client),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: 'Projets associés'),
                    const SizedBox(height: 14),
                    _CreateProjectButton(client: client),
                    const SizedBox(height: 14),
                    projectsAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, stackTrace) => AppEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Erreur',
                        description:
                            'Impossible de charger les projets du client.',
                        onRetry: () => ref.invalidate(projectControllerProvider),
                      ),
                      data: (projects) {
                        final clientProjects = projects
                            .where(
                              (project) => project.clientName == client.name,
                            )
                            .toList();

                        if (clientProjects.isEmpty) {
                          return const AppEmptyState(
                            icon: Icons.work_off_rounded,
                            title: 'Aucun projet',
                            description:
                                'Ce client n’a pas encore de projet associé.',
                          );
                        }

                        return _ClientProjects(projects: clientProjects);
                      },
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: 'Notes'),
                    const SizedBox(height: 14),
                    _NotesCard(client: client),
                  ],
                ),
              ),
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  ClientModel client,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer ce client ?'),
      content: Text(
        'Cette action supprimera définitivement "${client.name}". Elle est irréversible.',
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

  await ref.read(clientControllerProvider.notifier).deleteClient(client.id);

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Client supprimé.')),
  );

  context.pop();
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.client,
    required this.onEdit,
    required this.onDelete,
  });

  final ClientModel client;
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
                'Détail client',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(client.name, style: Theme.of(context).textTheme.titleLarge),
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

class _ClientInfoCard extends StatelessWidget {
  const _ClientInfoCard({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Text(
              client.name.substring(0, 1),
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            client.name,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            client.company,
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _StatusBadge(status: client.status),
          const SizedBox(height: 22),
          _InfoRow(
            icon: Icons.email_rounded,
            label: 'Email',
            value: client.email,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.phone_rounded,
            label: 'Téléphone',
            value: client.phone,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.work_rounded,
            label: 'Projets',
            value: '${client.projectsCount} projet(s)',
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.client});

  final ClientModel client;

  Future<void> _copyToClipboard(
    BuildContext context,
    String label,
    String value,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copié : $value')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _ActionItem(
        icon: Icons.call_rounded,
        title: 'Appeler',
        onTap: () => _copyToClipboard(context, 'Numéro', client.phone),
      ),
      _ActionItem(
        icon: Icons.email_rounded,
        title: 'Email',
        onTap: () => _copyToClipboard(context, 'Email', client.email),
      ),
      _ActionItem(
        icon: Icons.note_add_rounded,
        title: 'Note',
        onTap: () => _editNotes(context, ref),
      ),
    ];

    return Row(
      children: actions
          .map(
            (action) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: action.onTap,
                    child: Container(
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor(context),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(action.icon, color: AppTheme.primaryColor),
                          const SizedBox(height: 8),
                          Text(
                            action.title,
                            style: TextStyle(
                              color: AppTheme.mainTextColor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: client.notes);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Note client'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Ajoutez une note sur ce client...',
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
        .read(clientControllerProvider.notifier)
        .updateClient(client.copyWith(notes: result));
  }
}

class _CreateProjectButton extends StatelessWidget {
  const _CreateProjectButton({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push(
          '/projects/add?client=${Uri.encodeComponent(client.name)}',
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppTheme.cardColor(context)),
            const SizedBox(width: 8),
            Text(
              'Créer un projet pour ce client',
              style: TextStyle(
                color: AppTheme.cardColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientProjects extends StatelessWidget {
  const _ClientProjects({required this.projects});

  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: projects
          .map(
            (project) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProjectMiniCard(project: project),
            ),
          )
          .toList(),
    );
  }
}

class _ProjectMiniCard extends StatelessWidget {
  const _ProjectMiniCard({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final percent = (project.progress * 100).round();

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(
                  Icons.language_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  project.title,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AppStatusBadge(status: project.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: project.progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percent%',
                style: TextStyle(
                  color: AppTheme.mainTextColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends ConsumerWidget {
  const _NotesCard({required this.client});

  final ClientModel client;

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: client.notes);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Note client'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Ajoutez une note sur ce client...',
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
        .read(clientControllerProvider.notifier)
        .updateClient(client.copyWith(notes: result));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNotes = client.notes.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _editNotes(context, ref),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            hasNotes ? client.notes : 'Aucune note pour ce client. Touchez pour en ajouter une.',
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
              fontWeight: FontWeight.w800,
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
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'Actif':
        backgroundColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF16A34A);
        break;
      case 'En attente':
        backgroundColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        break;
      default:
        backgroundColor = const Color(0xFFEFF6FF);
        textColor = AppTheme.primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}
