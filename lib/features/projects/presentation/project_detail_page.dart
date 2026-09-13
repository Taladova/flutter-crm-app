import 'package:clientflow_pro/core/widgets/app_empty_state.dart';
import 'package:clientflow_pro/data/models/client_action_model.dart';
import 'package:clientflow_pro/data/models/deliverable_annotation_model.dart';
import 'package:clientflow_pro/data/models/deliverable_model.dart';
import 'package:clientflow_pro/data/models/deliverable_version_model.dart';
import 'package:clientflow_pro/data/models/task_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/currency_text.dart';
import '../../../core/utils/french_text.dart';
import '../../../core/utils/validation_file_opener.dart';
import '../../../core/widgets/app_filter_tabs.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/project_pulse_model.dart';
import '../../../data/services/project_pdf_service.dart';
import '../../../data/models/timeline_event_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../actions/providers/project_action_providers.dart';
import '../../clients/providers/client_providers.dart';
import '../../deliverables/providers/deliverable_providers.dart';
import '../providers/project_pulse_providers.dart';
import '../providers/project_providers.dart';

import '../../tasks/providers/task_providers.dart';
import '../../timeline/providers/timeline_providers.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabController = TabController(
    length: 3,
    vsync: this,
  );
  int selectedTabIndex = 0;

  static const tabLabels = ['Synthèse', 'Travail', 'Validations'];

  @override
  void initState() {
    super.initState();
    tabController.addListener(_syncTabIndex);
  }

  void _syncTabIndex() {
    if (selectedTabIndex == tabController.index ||
        tabController.indexIsChanging) {
      return;
    }
    setState(() => selectedTabIndex = tabController.index);
  }

  @override
  void dispose() {
    tabController.removeListener(_syncTabIndex);
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByIdProvider(widget.projectId));
    final projectTasks = ref.watch(tasksByProjectProvider(widget.projectId));
    final clients = ref.watch(clientControllerProvider).value ?? [];
    final linkedClient = project == null
        ? null
        : _findLinkedClient(clients, project.clientName);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: project == null
            ? const Center(child: Text('Projet introuvable'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProjectHeader(
                          project: project,
                          onEdit: () =>
                              context.push('/projects/${project.id}/edit'),
                          onDelete: () =>
                              _confirmDeleteProject(context, ref, project),
                          onExportPdf: () =>
                              _exportProjectPdf(context, project, projectTasks),
                          onInfo: () => _openInfoSheet(context, project),
                        ),
                        const SizedBox(height: 16),
                        _ProjectSummaryCard(
                          project: project,
                          percent: _progressPercent(project.progress),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AppFilterTabs(
                      labels: tabLabels,
                      selectedLabel: tabLabels[selectedTabIndex],
                      scrollable: false,
                      onSelected: (label) {
                        final index = tabLabels.indexOf(label);
                        setState(() => selectedTabIndex = index);
                        tabController.animateTo(index);
                      },
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: tabController,
                      children: [
                        _OverviewTab(project: project),
                        _WorkTab(project: project, tasks: projectTasks),
                        _ValidationsTab(project: project, client: linkedClient),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _openInfoSheet(BuildContext context, ProjectModel project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _ProjectInfoSheet(project: project),
    );
  }

  Future<void> _exportProjectPdf(
    BuildContext context,
    ProjectModel project,
    List<TaskModel> tasks,
  ) async {
    try {
      await ProjectPdfService.shareProjectReport(
        project: project,
        tasks: tasks,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de générer le PDF pour le moment.'),
        ),
      );
    }
  }
}

ClientModel? _findLinkedClient(List<ClientModel> clients, String clientName) {
  for (final client in clients) {
    if (client.name == clientName) return client;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Header + compact summary
// ---------------------------------------------------------------------------

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.onExportPdf,
    required this.onInfo,
  });

  final ProjectModel project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExportPdf;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.mainTextColor(context),
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Détail projet',
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Plus d’options',
          icon: Icon(
            Icons.more_horiz_rounded,
            color: AppTheme.mainTextColor(context),
          ),
          color: AppTheme.cardColor(context),
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
            if (value == 'pdf') onExportPdf();
            if (value == 'info') onInfo();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: _ProjectHeaderMenuItem(
                icon: Icons.edit_rounded,
                label: 'Modifier',
              ),
            ),
            PopupMenuItem(
              value: 'info',
              child: _ProjectHeaderMenuItem(
                icon: Icons.info_outline_rounded,
                label: 'Informations du projet',
              ),
            ),
            PopupMenuItem(
              value: 'pdf',
              child: _ProjectHeaderMenuItem(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Exporter en PDF',
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: _ProjectHeaderMenuItem(
                icon: Icons.delete_outline_rounded,
                label: 'Supprimer',
                isDestructive: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProjectHeaderMenuItem extends StatelessWidget {
  const _ProjectHeaderMenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppTheme.errorColor
        : AppTheme.mainTextColor(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ProjectSummaryCard extends StatelessWidget {
  const _ProjectSummaryCard({required this.project, required this.percent});

  final ProjectModel project;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${project.clientName} • ${project.type}',
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                project.status,
                style: TextStyle(
                  color: AppTheme.mainTextColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$percent %',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: _normalizedProgress(project.progress),
              minHeight: 7,
              backgroundColor: AppTheme.borderColor(context),
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectInfoSheet extends StatelessWidget {
  const _ProjectInfoSheet({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations complémentaires',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            _InfoRow(
              icon: Icons.payments_rounded,
              label: 'Budget',
              value: formatCurrencyText(project.budget),
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.category_rounded,
              label: 'Type',
              value: project.type,
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.event_rounded,
              label: 'Échéance',
              value: project.deadline,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Synthèse
// ---------------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _CompactPulseCard(projectId: project.id),
        const SizedBox(height: 20),
        _ProjectSummarySection(project: project),
        const SizedBox(height: 20),
        _CompactTimelineSection(project: project),
      ],
    );
  }
}

class _ProjectSummarySection extends StatelessWidget {
  const _ProjectSummarySection({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Résumé'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: _cardDecoration(context),
          child: Column(
            children: [
              _SummaryLine(label: 'Statut', value: project.status),
              Divider(height: 1, color: AppTheme.borderColor(context)),
              _SummaryLine(
                label: 'Budget',
                value: project.budget.trim().isEmpty
                    ? 'Non renseigné'
                    : formatCurrencyText(project.budget),
              ),
              Divider(height: 1, color: AppTheme.borderColor(context)),
              _SummaryLine(
                label: 'Échéance',
                value: project.deadline.trim().isEmpty
                    ? 'Non définie'
                    : project.deadline,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.mainTextColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactPulseCard extends ConsumerWidget {
  const _CompactPulseCard({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulseState = ref.watch(projectPulseProvider(projectId));

    return pulseState.when(
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(context),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(context),
        child: Text(
          'Impossible de calculer l’état du projet.',
          style: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      data: (pulse) {
        final color = _pulseColor(pulse.status);
        final percent = _progressPercent(pulse.progress);
        final isCompleted = pulse.status == ProjectPulseStatus.completed;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'État du projet',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.circle_rounded,
                    color: color,
                    size: isCompleted ? 20 : 10,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pulse.label,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (!isCompleted)
                    Text(
                      '$percent %',
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                pulse.reason,
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              if (!isCompleted && pulse.daysBlocked > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'En attente depuis ${frDays(pulse.daysBlocked)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (isCompleted && pulse.lastActivityLabel != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Dernière activité',
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${pulse.lastActivityLabel} • ${_relativeTime(pulse.lastActivity)}',
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CompactTimelineSection extends ConsumerWidget {
  const _CompactTimelineSection({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineState = ref.watch(timelineByProjectProvider(project.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Résumé de la timeline'),
        const SizedBox(height: 12),
        timelineState.when(
          loading: () => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(context),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Suivi indisponible',
            description: 'Impossible de charger les étapes du projet.',
          ),
          data: (events) {
            if (events.isEmpty) {
              return _CompactEmptyRow(
                text: 'Aucune étape pour ce projet.',
                onTap: () => _openTimelineSheet(context, project),
              );
            }

            final nextStep = _nextTimelineStep(events);
            final preview = events.take(5).toList();

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nextStep != null) ...[
                    _NextTimelineStepCard(event: nextStep),
                    const SizedBox(height: 14),
                  ],
                  for (var i = 0; i < preview.length; i++)
                    _TimelineMiniRow(
                      event: preview[i],
                      isLast: i == preview.length - 1,
                    ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _openTimelineSheet(context, project),
                    child: Text(
                      'Voir tout le suivi →',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _openTimelineSheet(BuildContext context, ProjectModel project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: _ProjectTimelineSection(project: project),
        ),
      ),
    );
  }
}

class _NextTimelineStepCard extends StatelessWidget {
  const _NextTimelineStepCard({required this.event});

  final TimelineEventModel event;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: AppTheme.primaryColor,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prochaine étape',
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.date == null
                      ? event.title
                      : '${event.title} • ${_formatActionDate(event.date!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
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

class _TimelineMiniRow extends StatelessWidget {
  const _TimelineMiniRow({required this.event, required this.isLast});

  final TimelineEventModel event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = _timelineStatusColor(event.status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(_timelineStatusIcon(event.status), color: color, size: 18),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: AppTheme.borderColor(context),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.mainTextColor(context),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactEmptyRow extends StatelessWidget {
  const _CompactEmptyRow({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: _cardDecoration(context),
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Travail
// ---------------------------------------------------------------------------

class _WorkTab extends StatelessWidget {
  const _WorkTab({required this.project, required this.tasks});

  final ProjectModel project;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final clients = ref.watch(clientControllerProvider).value ?? [];
        final linkedClient = _findLinkedClient(clients, project.clientName);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _ProjectActionsSection(project: project, client: linkedClient),
            const SizedBox(height: 24),
            _CompactTasksSection(project: project, tasks: tasks),
          ],
        );
      },
    );
  }
}

class _CompactTasksSection extends StatelessWidget {
  const _CompactTasksSection({required this.project, required this.tasks});

  final ProjectModel project;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionTitle(title: 'Tâches', count: tasks.length),
            const Spacer(),
            _AddActionButton(
              label: 'Ajouter',
              onTap: () {
                context.push(
                  '/tasks/add?projectId=${project.id}&projectName=${Uri.encodeComponent(project.title)}',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          const AppEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Aucune tâche',
            description: 'Ajoutez votre première tâche pour ce projet.',
          )
        else
          Container(
            decoration: _cardDecoration(context),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < tasks.length; i++)
                  _CompactTaskRow(
                    task: tasks[i],
                    isLast: i == tasks.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CompactTaskRow extends ConsumerWidget {
  const _CompactTaskRow({required this.task, required this.isLast});

  final TaskModel task;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = task.status == 'Terminé';

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/tasks/${task.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => ref
                        .read(taskControllerProvider.notifier)
                        .toggleTaskStatus(task),
                    child: Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isDone
                          ? const Color(0xFF16A34A)
                          : AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    task.deadline,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryTextColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, color: AppTheme.borderColor(context)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Validations
// ---------------------------------------------------------------------------

class _ValidationsTab extends StatelessWidget {
  const _ValidationsTab({required this.project, required this.client});

  final ProjectModel project;
  final ClientModel? client;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [_ProjectDeliverablesSection(project: project, client: client)],
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

class _ProjectActionsSection extends ConsumerWidget {
  const _ProjectActionsSection({required this.project, required this.client});

  final ProjectModel project;
  final ClientModel? client;

  Future<void> _openActionSheet(
    BuildContext context,
    WidgetRef ref, {
    ClientActionModel? action,
  }) async {
    final professionalUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (professionalUid == null) return;

    final timelineEvents =
        ref.read(timelineByProjectProvider(project.id)).value ??
        const <TimelineEventModel>[];

    final titleController = TextEditingController(text: action?.title ?? '');
    final descriptionController = TextEditingController(
      text: action?.description ?? '',
    );
    var assignedTo = action?.assignedTo ?? 'professional';
    var type = action?.type ?? 'other';
    var priority = action?.priority ?? 'medium';
    var status = action?.status ?? 'pending';
    var stageId = action?.stageId ?? '';
    var visibleToClient = action?.visibleToClient ?? true;
    var dueDate = action?.dueDate;

    final result = await showModalBottomSheet<ClientActionModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickDate() async {
              final selected = await showDatePicker(
                context: context,
                initialDate: dueDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (selected == null) return;
              setSheetState(() => dueDate = selected);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action == null
                          ? 'Ajouter une action'
                          : 'Modifier l’action',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titre',
                        hintText: 'Ex : Valider la maquette Homepage',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Ajoutez le contexte utile...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ActionDropdown(
                      label: 'Responsable',
                      value: assignedTo,
                      items: const {
                        'professional': 'Moi / équipe',
                        'client': 'Client',
                      },
                      onChanged: (value) =>
                          setSheetState(() => assignedTo = value),
                    ),
                    if (timelineEvents.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ActionDropdown(
                        label: 'Étape du projet',
                        value: stageId,
                        items: {
                          '': 'Aucune étape',
                          for (final event in timelineEvents)
                            event.id: event.title,
                        },
                        onChanged: (value) =>
                            setSheetState(() => stageId = value),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionDropdown(
                            label: 'Type',
                            value: type,
                            items: const {
                              'task': 'Tâche',
                              'validation': 'Validation',
                              'document': 'Document',
                              'information': 'Information',
                              'other': 'Autre',
                            },
                            onChanged: (value) =>
                                setSheetState(() => type = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionDropdown(
                            label: 'Priorité',
                            value: priority,
                            items: const {
                              'high': 'Haute',
                              'medium': 'Moyenne',
                              'low': 'Basse',
                            },
                            onChanged: (value) =>
                                setSheetState(() => priority = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionDropdown(
                            label: 'Statut',
                            value: status,
                            items: const {
                              'pending': 'En attente',
                              'completed': 'Terminé',
                              'cancelled': 'Annulé',
                            },
                            onChanged: (value) =>
                                setSheetState(() => status = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickDate,
                            icon: const Icon(Icons.event_rounded, size: 18),
                            label: Text(
                              dueDate == null
                                  ? 'Échéance'
                                  : _formatActionDate(dueDate!),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: visibleToClient,
                      activeThumbColor: AppTheme.primaryColor,
                      title: const Text('Visible côté client'),
                      onChanged: (value) =>
                          setSheetState(() => visibleToClient = value),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          final now = DateTime.now();
                          Navigator.of(context).pop(
                            ClientActionModel(
                              id:
                                  action?.id ??
                                  'action_${now.millisecondsSinceEpoch}',
                              professionalUid: professionalUid,
                              clientId: client?.id ?? action?.clientId ?? '',
                              projectId: project.id,
                              title: title,
                              description: descriptionController.text.trim(),
                              assignedTo: assignedTo,
                              type: type,
                              priority: priority,
                              status: status,
                              stageId: stageId,
                              dueDate: dueDate,
                              createdAt: action?.createdAt ?? now,
                              updatedAt: now,
                              completedAt: status == 'completed'
                                  ? action?.completedAt ?? now
                                  : null,
                              visibleToClient: visibleToClient,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          action == null ? 'Créer l’action' : 'Enregistrer',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();

    if (result == null) return;

    if (action == null) {
      await ref
          .read(projectActionControllerProvider.notifier)
          .addAction(result);
    } else {
      await ref
          .read(projectActionControllerProvider.notifier)
          .updateAction(result);
    }
  }

  Future<void> _deleteAction(
    BuildContext context,
    WidgetRef ref,
    ClientActionModel action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette action ?'),
        content: Text('"${action.title}" sera supprimée définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref
        .read(projectActionControllerProvider.notifier)
        .deleteAction(action);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsState = ref.watch(projectActionsByProjectProvider(project.id));

    return actionsState.when(
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(context),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Actions indisponibles',
        description: 'Impossible de charger les actions du projet.',
        onRetry: () => ref.invalidate(projectActionControllerProvider),
      ),
      data: (actions) {
        final pendingActions = actions
            .where((action) => action.status == 'pending')
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SectionTitle(title: 'Actions', count: pendingActions.length),
                const Spacer(),
                _AddActionButton(
                  label: 'Ajouter',
                  onTap: () => _openActionSheet(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (actions.isEmpty)
              AppEmptyState(
                icon: Icons.bolt_rounded,
                title: 'Aucune action',
                description:
                    'Créez les validations, demandes ou réponses importantes à suivre.',
              )
            else
              Column(
                children: actions
                    .map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProjectActionCard(
                          action: action,
                          onComplete: action.status == 'pending'
                              ? () => ref
                                    .read(
                                      projectActionControllerProvider.notifier,
                                    )
                                    .completeAction(action)
                              : null,
                          onEdit: () =>
                              _openActionSheet(context, ref, action: action),
                          onDelete: () => _deleteAction(context, ref, action),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}

class _ProjectActionCard extends StatelessWidget {
  const _ProjectActionCard({
    required this.action,
    required this.onEdit,
    required this.onDelete,
    this.onComplete,
  });

  final ClientActionModel action;
  final VoidCallback? onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = action.status == 'completed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onComplete,
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isCompleted
                      ? const Color(0xFF16A34A)
                      : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.title,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: AppTheme.secondaryTextColor(context),
                ),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
          if (action.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              action.description,
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                icon: Icons.person_rounded,
                label: _assignedToLabel(action.assignedTo),
              ),
              _ActionChip(
                icon: Icons.flag_rounded,
                label: _priorityLabel(action.priority),
                color: _priorityColor(action.priority),
              ),
              if (action.dueDate != null)
                _ActionChip(
                  icon: Icons.event_rounded,
                  label: _formatActionDate(action.dueDate!),
                ),
              _ActionChip(
                icon: action.visibleToClient
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                label: action.visibleToClient ? 'Visible client' : 'Interne',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: chipColor, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionDropdown extends StatelessWidget {
  const _ActionDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: items.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _AddActionButton extends StatelessWidget {
  const _AddActionButton({required this.onTap, this.label = 'Ajouter'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
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

// ---------------------------------------------------------------------------
// Validations
// ---------------------------------------------------------------------------

class _ProjectDeliverablesSection extends ConsumerWidget {
  const _ProjectDeliverablesSection({
    required this.project,
    required this.client,
  });

  final ProjectModel project;
  final ClientModel? client;

  Future<void> _openDeliverableSheet(
    BuildContext context,
    WidgetRef ref, {
    DeliverableModel? deliverable,
  }) async {
    final titleController = TextEditingController(text: deliverable?.title);
    final descriptionController = TextEditingController(
      text: deliverable?.description,
    );
    final urlController = TextEditingController();
    var kind = deliverable?.kind ?? 'image';
    PlatformFile? selectedFile;
    String? formError;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void submit() {
              if (deliverable == null && titleController.text.trim().isEmpty) {
                setSheetState(() => formError = 'Le titre est obligatoire.');
                return;
              }
              if (deliverable == null && client == null) {
                setSheetState(
                  () => formError = 'Aucun client lié à ce projet.',
                );
                return;
              }
              if (urlController.text.trim().isEmpty &&
                  selectedFile?.bytes == null) {
                setSheetState(
                  () => formError =
                      'Ajoutez une URL externe ou un fichier avant d\'envoyer.',
                );
                return;
              }
              Navigator.pop(context, true);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deliverable == null
                          ? 'Créer une validation'
                          : 'Ajouter une version',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Le client recevra une action de validation.',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (deliverable == null) ...[
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre',
                          hintText: 'Ex : Homepage',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Contexte de validation pour le client',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ActionDropdown(
                        label: 'Type',
                        value: kind,
                        items: const {
                          'image': 'Image',
                          'pdf': 'PDF',
                          'file': 'Fichier',
                          'url': 'URL',
                        },
                        onChanged: (value) => setSheetState(() => kind = value),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL externe',
                        hintText: 'https://...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DeliverableFilePicker(
                      fileName: selectedFile?.name,
                      onPick: () async {
                        final result = await FilePicker.platform.pickFiles(
                          withData: true,
                          allowMultiple: false,
                        );
                        final file = result?.files.single;
                        if (file == null) return;
                        setSheetState(() {
                          selectedFile = file;
                          formError = null;
                        });
                      },
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        formError!,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: submit,
                        icon: const Icon(Icons.send_rounded),
                        label: Text(
                          deliverable == null
                              ? 'Envoyer en validation'
                              : 'Envoyer la nouvelle version',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final externalUrl = urlController.text.trim();
    final file = selectedFile;
    titleController.dispose();
    descriptionController.dispose();
    urlController.dispose();

    if (result != true) return;
    if (deliverable == null && (title.isEmpty || client == null)) return;
    if (externalUrl.isEmpty && file?.bytes == null) return;

    final fileName = file?.name ?? externalUrl;
    final mimeType = file == null
        ? 'text/uri-list'
        : _mimeTypeFromName(file.name);

    try {
      if (deliverable == null) {
        await ref
            .read(deliverableControllerProvider.notifier)
            .createDeliverable(
              projectId: project.id,
              clientId: client?.id ?? '',
              title: title,
              description: description,
              kind: kind,
              fileName: fileName,
              mimeType: mimeType,
              externalUrl: externalUrl,
              bytes: file?.bytes,
            );
      } else {
        await ref
            .read(deliverableControllerProvider.notifier)
            .addVersion(
              deliverable: deliverable,
              fileName: fileName,
              mimeType: mimeType,
              externalUrl: externalUrl,
              bytes: file?.bytes,
            );
      }
    } catch (error) {
      if (!context.mounted) return;
      final message = error.toString().contains('firebase_storage')
          ? 'Impossible d’envoyer le fichier. Vérifiez Storage puis réessayez.'
          : 'Impossible d’ajouter cet élément pour le moment.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deliverable == null ? 'Élément ajouté' : 'Version ajoutée',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliverablesState = ref.watch(
      deliverablesByProjectProvider(project.id),
    );

    return deliverablesState.when(
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(context),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Validations indisponibles',
        description: 'Impossible de charger les validations du projet.',
        onRetry: () => ref.invalidate(deliverableControllerProvider),
      ),
      data: (deliverables) {
        final awaiting = deliverables
            .where((deliverable) => deliverable.status == 'awaitingReview')
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SectionTitle(
                  title: 'Éléments à valider',
                  count: deliverables.length,
                ),
                const Spacer(),
                _AddActionButton(
                  label: 'Ajouter',
                  onTap: () => _openDeliverableSheet(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (deliverables.isEmpty)
              _CompactEmptyRow(
                text:
                    'Aucun élément à valider. Ajoutez une maquette, un PDF, un logo ou une URL à faire valider.',
                onTap: () => _openDeliverableSheet(context, ref),
              )
            else ...[
              if (awaiting > 0) ...[
                _DeliverableSummaryBanner(awaiting: awaiting),
                const SizedBox(height: 12),
              ],
              ...deliverables.map((deliverable) {
                final versions = ref.watch(
                  deliverableVersionsByDeliverableProvider(deliverable.id),
                );
                final annotations = versions.isEmpty
                    ? const <DeliverableAnnotationModel>[]
                    : ref.watch(
                        deliverableAnnotationsByVersionProvider(
                          versions.first.id,
                        ),
                      );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DeliverableCard(
                    deliverable: deliverable,
                    versions: versions,
                    annotations: annotations,
                    onResolveAnnotation: (annotation) => ref
                        .read(deliverableAnnotationsProvider.notifier)
                        .resolveAnnotation(annotation),
                    onAddVersion: () => _openDeliverableSheet(
                      context,
                      ref,
                      deliverable: deliverable,
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }
}

class _DeliverableSummaryBanner extends StatelessWidget {
  const _DeliverableSummaryBanner({required this.awaiting});

  final int awaiting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${frPlural(awaiting, 'élément attend', 'éléments attendent')} une validation client',
              style: TextStyle(
                color: AppTheme.mainTextColor(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliverableCard extends StatelessWidget {
  const _DeliverableCard({
    required this.deliverable,
    required this.versions,
    required this.annotations,
    required this.onResolveAnnotation,
    required this.onAddVersion,
  });

  final DeliverableModel deliverable;
  final List<DeliverableVersionModel> versions;
  final List<DeliverableAnnotationModel> annotations;
  final ValueChanged<DeliverableAnnotationModel> onResolveAnnotation;
  final VoidCallback onAddVersion;

  @override
  Widget build(BuildContext context) {
    final latest = versions.isEmpty ? null : versions.first;
    final color = _deliverableStatusColor(deliverable.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(_deliverableIcon(deliverable.kind), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deliverable.title,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Version actuelle V${deliverable.currentVersion}',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _DeliverableStatusPill(status: deliverable.status),
            ],
          ),
          if (deliverable.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              deliverable.description,
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          if (latest != null && latest.previewUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openValidationVersionFile(
                context: context,
                deliverable: deliverable,
                version: latest,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Ouvrir la dernière version'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Historique',
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...versions.map(
            (version) => _DeliverableVersionRow(version: version),
          ),
          if (annotations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Annotations image',
              style: TextStyle(
                color: AppTheme.mainTextColor(context),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ...annotations.asMap().entries.map(
              (entry) => _ProAnnotationRow(
                number: entry.key + 1,
                annotation: entry.value,
                onResolve: () => onResolveAnnotation(entry.value),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAddVersion,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une version'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliverableVersionRow extends StatelessWidget {
  const _DeliverableVersionRow({required this.version});

  final DeliverableVersionModel version;

  @override
  Widget build(BuildContext context) {
    final color = _deliverableStatusColor(version.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.pageBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        children: [
          Text(
            'V${version.versionNumber}',
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _deliverableStatusLabel(version.status),
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          if (version.reviewedAt != null)
            Text(
              _formatActionDate(version.reviewedAt!),
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProAnnotationRow extends StatelessWidget {
  const _ProAnnotationRow({
    required this.number,
    required this.annotation,
    required this.onResolve,
  });

  final int number;
  final DeliverableAnnotationModel annotation;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.pageBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: annotation.resolved
                  ? const Color(0xFF16A34A)
                  : AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  annotation.comment,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  annotation.resolved ? 'Résolu' : 'À traiter',
                  style: TextStyle(
                    color: annotation.resolved
                        ? const Color(0xFF16A34A)
                        : AppTheme.secondaryTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (!annotation.resolved)
            TextButton(onPressed: onResolve, child: const Text('Résolu')),
        ],
      ),
    );
  }
}

class _DeliverableStatusPill extends StatelessWidget {
  const _DeliverableStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _deliverableStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _deliverableStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DeliverableFilePicker extends StatelessWidget {
  const _DeliverableFilePicker({required this.fileName, required this.onPick});

  final String? fileName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: const Icon(Icons.attach_file_rounded),
      label: Text(fileName == null ? 'Joindre un fichier' : fileName!),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline complète (ouverte en bottom sheet depuis Synthèse)
// ---------------------------------------------------------------------------

class _ProjectTimelineSection extends ConsumerWidget {
  const _ProjectTimelineSection({required this.project});

  final ProjectModel project;

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref, {
    TimelineEventModel? event,
    int? nextOrder,
  }) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    final titleController = TextEditingController(text: event?.title ?? '');
    final descriptionController = TextEditingController(
      text: event?.description ?? '',
    );
    var status = event?.status ?? 'upcoming';
    var visibleToClient = event?.visibleToClient ?? true;
    var date = event?.date;

    final result = await showModalBottomSheet<TimelineEventModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> pickDate() async {
              final selected = await showDatePicker(
                context: sheetContext,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (selected == null) return;
              setSheetState(() => date = selected);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event == null ? 'Ajouter une étape' : 'Modifier l’étape',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titre',
                        hintText: 'Ex : Validation homepage',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionDropdown(
                            label: 'Statut',
                            value: status,
                            items: const {
                              'upcoming': 'À venir',
                              'current': 'En cours',
                              'completed': 'Terminée',
                            },
                            onChanged: (value) =>
                                setSheetState(() => status = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickDate,
                            icon: const Icon(Icons.event_rounded, size: 18),
                            label: Text(
                              date == null ? 'Date' : _formatActionDate(date!),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: visibleToClient,
                      activeThumbColor: AppTheme.primaryColor,
                      title: const Text('Visible côté client'),
                      onChanged: (value) =>
                          setSheetState(() => visibleToClient = value),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          final now = DateTime.now();
                          Navigator.of(sheetContext).pop(
                            TimelineEventModel(
                              id:
                                  event?.id ??
                                  'timeline_${now.millisecondsSinceEpoch}',
                              projectId: project.id,
                              professionalUid: uid,
                              title: title,
                              description: descriptionController.text.trim(),
                              status: status,
                              order: event?.order ?? nextOrder ?? 1000,
                              visibleToClient: visibleToClient,
                              date: date,
                              createdAt: event?.createdAt ?? now,
                              updatedAt: now,
                            ),
                          );
                        },
                        icon: Icon(
                          event == null
                              ? Icons.add_rounded
                              : Icons.save_rounded,
                        ),
                        label: Text(event == null ? 'Ajouter' : 'Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    if (result == null) return;

    final controller = ref.read(timelineControllerProvider.notifier);
    if (event == null) {
      await controller.addEvent(result);
    } else {
      await controller.updateEvent(result);
    }

    if (result.status == 'current') {
      await controller.setCurrent(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineState = ref.watch(timelineByProjectProvider(project.id));

    return timelineState.when(
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(context),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Suivi indisponible',
        description: 'Impossible de charger les étapes du projet.',
      ),
      data: (events) {
        final nextOrder = events.isEmpty
            ? 1000
            : events
                      .map((event) => event.order)
                      .reduce((a, b) => a > b ? a : b) +
                  1000;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SectionTitle(
                      title: 'Suivi du projet',
                      count: events.length,
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () =>
                        _openSheet(context, ref, nextOrder: nextOrder),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (events.isEmpty)
                Text(
                  'Aucune étape réelle pour ce projet.',
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                ...events.map(
                  (event) => _ProfessionalTimelineTile(
                    event: event,
                    onEdit: () => _openSheet(context, ref, event: event),
                    onDelete: () => ref
                        .read(timelineControllerProvider.notifier)
                        .deleteEvent(event),
                    onComplete: () => ref
                        .read(timelineControllerProvider.notifier)
                        .updateEvent(event.copyWith(status: 'completed')),
                    onCurrent: () => ref
                        .read(timelineControllerProvider.notifier)
                        .setCurrent(event),
                    onMoveUp: () => ref
                        .read(timelineControllerProvider.notifier)
                        .moveEvent(event, -1),
                    onMoveDown: () => ref
                        .read(timelineControllerProvider.notifier)
                        .moveEvent(event, 1),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfessionalTimelineTile extends StatelessWidget {
  const _ProfessionalTimelineTile({
    required this.event,
    required this.onEdit,
    required this.onDelete,
    required this.onComplete,
    required this.onCurrent,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final TimelineEventModel event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onComplete;
  final VoidCallback onCurrent;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final color = _timelineStatusColor(event.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(_timelineStatusIcon(event.status), color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                  break;
                case 'complete':
                  onComplete();
                  break;
                case 'current':
                  onCurrent();
                  break;
                case 'up':
                  onMoveUp();
                  break;
                case 'down':
                  onMoveDown();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'complete', child: Text('Marquer terminée')),
              PopupMenuItem(value: 'current', child: Text('Définir actuelle')),
              PopupMenuItem(value: 'up', child: Text('Monter')),
              PopupMenuItem(value: 'down', child: Text('Descendre')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aides & dialogues partagés
// ---------------------------------------------------------------------------

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

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Projet supprimé.')));

  context.pop();
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
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

String _assignedToLabel(String assignedTo) {
  return assignedTo == 'client' ? 'Client' : 'Moi';
}

Color _pulseColor(ProjectPulseStatus status) {
  switch (status) {
    case ProjectPulseStatus.onTrack:
      return const Color(0xFF16A34A);
    case ProjectPulseStatus.waitingClient:
      return const Color(0xFFD97706);
    case ProjectPulseStatus.needsAttention:
      return const Color(0xFFDC2626);
    case ProjectPulseStatus.completed:
      return AppTheme.primaryColor;
  }
}

IconData _timelineStatusIcon(String status) {
  switch (status) {
    case 'completed':
      return Icons.check_circle_rounded;
    case 'current':
      return Icons.radio_button_checked_rounded;
    default:
      return Icons.radio_button_unchecked_rounded;
  }
}

Color _timelineStatusColor(String status) {
  switch (status) {
    case 'completed':
      return const Color(0xFF16A34A);
    case 'current':
      return AppTheme.primaryColor;
    default:
      return AppTheme.lightSecondaryTextColor;
  }
}

TimelineEventModel? _nextTimelineStep(List<TimelineEventModel> events) {
  for (final event in events) {
    if (event.status == 'current') return event;
  }

  for (final event in events) {
    if (event.status == 'upcoming') return event;
  }

  return null;
}

String _relativeTime(DateTime? date) {
  if (date == null) return 'date inconnue';

  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  return 'il y a ${diff.inDays} jours';
}

String _priorityLabel(String priority) {
  switch (priority) {
    case 'high':
      return 'Haute';
    case 'low':
      return 'Basse';
    default:
      return 'Moyenne';
  }
}

Color _priorityColor(String priority) {
  switch (priority) {
    case 'high':
      return const Color(0xFFDC2626);
    case 'low':
      return const Color(0xFF2563EB);
    default:
      return const Color(0xFFD97706);
  }
}

String _formatActionDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

int _progressPercent(double progress) {
  return (_normalizedProgress(progress) * 100).round();
}

double _normalizedProgress(double progress) {
  final normalized = progress > 1 ? progress / 100 : progress;
  return normalized.clamp(0.0, 1.0);
}

String _deliverableStatusLabel(String status) {
  switch (status) {
    case 'approved':
      return 'Validé';
    case 'changesRequested':
      return 'Modifs demandées';
    default:
      return 'À valider';
  }
}

Color _deliverableStatusColor(String status) {
  switch (status) {
    case 'approved':
      return const Color(0xFF16A34A);
    case 'changesRequested':
      return const Color(0xFFD97706);
    default:
      return AppTheme.primaryColor;
  }
}

IconData _deliverableIcon(String kind) {
  switch (kind) {
    case 'image':
      return Icons.image_rounded;
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'url':
      return Icons.link_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

String _mimeTypeFromName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'application/octet-stream';
}

BoxDecoration _cardDecoration(BuildContext context) {
  return BoxDecoration(
    color: AppTheme.cardColor(context),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppTheme.borderColor(context)),
    boxShadow: [
      if (!AppTheme.isDark(context))
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
    ],
  );
}
