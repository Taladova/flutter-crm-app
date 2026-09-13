import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/validation_file_opener.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../data/models/client_action_model.dart';
import '../../../data/models/deliverable_model.dart';
import '../../../data/models/deliverable_version_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/services/project_pdf_service.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/timeline_event_model.dart';
import '../providers/client_portal_providers.dart';
import 'client_portal_theme.dart';
import 'widgets/client_deliverable_review_sheet.dart';

class ClientProjectDetailPage extends ConsumerStatefulWidget {
  const ClientProjectDetailPage({
    super.key,
    required this.projectId,
    this.initialTabIndex = 0,
  });

  final String projectId;
  final int initialTabIndex;

  @override
  ConsumerState<ClientProjectDetailPage> createState() =>
      _ClientProjectDetailPageState();
}

class _ClientProjectDetailPageState
    extends ConsumerState<ClientProjectDetailPage>
    with SingleTickerProviderStateMixin {
  List<ProjectModel>? _lastProjects;
  bool _loggedProjectsError = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void didUpdateWidget(covariant ClientProjectDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.initialTabIndex.clamp(0, 2);
    if (oldWidget.initialTabIndex != widget.initialTabIndex &&
        _tabController.index != nextIndex) {
      _tabController.index = nextIndex;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(clientHomeProjectsProvider);
    final actionsAsync = ref.watch(clientHomeActionsProvider);
    final tasksAsync = ref.watch(clientProgressTasksProvider);
    final timelineAsync = ref.watch(
      clientPortalTimelineProvider(widget.projectId),
    );
    final deliverablesAsync = ref.watch(
      clientProjectDeliverablesProvider(widget.projectId),
    );
    final versionsAsync = ref.watch(
      clientProjectDeliverableVersionsProvider(widget.projectId),
    );
    final latestProjects = projectsAsync.value;

    if (latestProjects != null) {
      _lastProjects = latestProjects;
      _loggedProjectsError = false;
    } else if (projectsAsync.hasError && !_loggedProjectsError) {
      _loggedProjectsError = true;
      // ignore: avoid_print
      print(
        '[client-project-detail] projects error\n'
        'projectId=${widget.projectId}\n'
        'error=${projectsAsync.error}',
      );
    }

    final projects = latestProjects ?? _lastProjects;
    final hasInitialProjects = projects != null;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: !hasInitialProjects && projectsAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : !hasInitialProjects && projectsAsync.hasError
            ? AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Projet indisponible',
                description: 'Impossible de charger ce projet.',
                onRetry: () => ref.invalidate(clientHomeProjectsProvider),
              )
            : Builder(
                builder: (context) {
                  final visibleProjects = projects ?? const <ProjectModel>[];
                  final project = _findProject(
                    visibleProjects,
                    widget.projectId,
                  );
                  if (project == null) {
                    return const AppEmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Projet inaccessible',
                      description:
                          'Ce projet n’est pas lié à votre espace client.',
                    );
                  }

                  final actions =
                      (actionsAsync.value ?? const <ClientActionModel>[])
                          .where(
                            (action) =>
                                action.projectId == project.id &&
                                action.visibleToClient,
                          )
                          .toList();
                  final timeline =
                      timelineAsync.value ?? const <TimelineEventModel>[];
                  final deliverables =
                      (deliverablesAsync.value ?? const <DeliverableModel>[])
                          .where(
                            (deliverable) =>
                                deliverable.projectId == project.id,
                          )
                          .toList();
                  final versions =
                      versionsAsync.value ?? const <DeliverableVersionModel>[];
                  final tasks =
                      (tasksAsync.value ?? const <TaskModel>[])
                          .where(
                            (task) =>
                                task.projectId == project.id &&
                                task.isVisibleInClientPortal,
                          )
                          .toList()
                        ..sort(_compareTasks);

                  return NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                          child: _ClientProjectHeader(
                            project: project,
                            onBack: () => _goBackToClientHome(context),
                            onExportPdf: () => _exportClientProjectPdf(
                              context,
                              project,
                              tasks,
                            ),
                          ),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _TabsHeaderDelegate(
                          child: Container(
                            color: AppTheme.pageBackground(context),
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                            child: _ProjectTabs(controller: _tabController),
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _ClientProjectSummaryTab(
                          project: project,
                          timeline: timeline,
                        ),
                        _ClientProjectWorkTab(
                          project: project,
                          tasks: tasks,
                          actions: actions,
                        ),
                        _ClientProjectValidationsTab(
                          deliverables: deliverables,
                          versions: versions,
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _exportClientProjectPdf(
    BuildContext context,
    ProjectModel project,
    List<TaskModel> visibleTasks,
  ) async {
    try {
      await ProjectPdfService.shareProjectReport(
        project: project,
        tasks: visibleTasks,
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

class _ClientProjectHeader extends StatelessWidget {
  const _ClientProjectHeader({
    required this.project,
    required this.onBack,
    required this.onExportPdf,
  });

  final ProjectModel project;
  final VoidCallback onBack;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    final percent = _progressPercent(project.progress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton.outlined(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Détail projet',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton.outlined(
              tooltip: 'Télécharger le PDF',
              onPressed: onExportPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                project.type.isEmpty ? project.clientName : project.type,
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    project.status,
                    style: TextStyle(
                      color: AppTheme.mainTextColor(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$percent %',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: _normalizedProgress(project.progress),
                  backgroundColor: AppTheme.borderColor(context),
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _goBackToClientHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/client/home');
}

class _ProjectTabs extends StatelessWidget {
  const _ProjectTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.secondarySurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.secondaryTextColor(context),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        indicator: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: const [
          Tab(text: 'Synthèse'),
          Tab(text: 'Travail'),
          Tab(text: 'Validations'),
        ],
      ),
    );
  }
}

class _ClientProjectSummaryTab extends StatelessWidget {
  const _ClientProjectSummaryTab({
    required this.project,
    required this.timeline,
  });

  final ProjectModel project;
  final List<TimelineEventModel> timeline;

  @override
  Widget build(BuildContext context) {
    final visibleTimeline = timeline
        .where((event) => event.visibleToClient)
        .toList();
    final nextStepLabel = project.nextStep.trim().isNotEmpty
        ? project.nextStep.trim()
        : _nextTimelineStep(visibleTimeline)?.title ?? 'Aucune étape prévue';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _InfoCard(
          children: [
            _InfoRow(label: 'Statut', value: project.status),
            _InfoRow(
              label: 'Échéance',
              value: project.deadline.isEmpty
                  ? 'Non définie'
                  : project.deadline,
            ),
            _InfoRow(
              label: 'Prochaine étape',
              value: nextStepLabel,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Étapes visibles', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (visibleTimeline.isEmpty)
          const AppEmptyState(
            icon: Icons.route_rounded,
            title: 'Aucune étape',
            description: 'Les étapes partagées apparaîtront ici.',
          )
        else
          _TimelineCard(events: visibleTimeline),
      ],
    );
  }
}

class _ClientProjectWorkTab extends ConsumerWidget {
  const _ClientProjectWorkTab({
    required this.project,
    required this.tasks,
    required this.actions,
  });

  final ProjectModel project;
  final List<TaskModel> tasks;
  final List<ClientActionModel> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientActions =
        actions
            .where(
              (action) =>
                  action.assignedTo == 'client' && action.type != 'task',
            )
            .toList()
          ..sort(_compareActions);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text('Mes tâches', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        _TaskStatusSummary(tasks: tasks),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          const AppEmptyState(
            icon: Icons.checklist_rounded,
            title: 'Aucune tâche visible',
            description:
                'Les tâches internes de votre prestataire ne sont pas affichées.',
          )
        else
          _ProjectTaskGroup(projectTitle: project.title, tasks: tasks),
        const SizedBox(height: 18),
        Text(
          'À faire de votre côté',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (clientActions.isEmpty)
          const AppEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Tout est à jour',
            description:
                'Aucune action client n’est en attente pour ce projet.',
          )
        else
          ...clientActions.map(
            (action) => _ClientWorkTile(
              action: action,
              onTap: () => _openClientAction(context, ref, action),
            ),
          ),
      ],
    );
  }
}

class _ClientProjectValidationsTab extends ConsumerWidget {
  const _ClientProjectValidationsTab({
    required this.deliverables,
    required this.versions,
  });

  final List<DeliverableModel> deliverables;
  final List<DeliverableVersionModel> versions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortedDeliverables = [...deliverables]
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1900);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1900);
        return bDate.compareTo(aDate);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (sortedDeliverables.isEmpty)
          const AppEmptyState(
            icon: Icons.verified_outlined,
            title: 'Aucune validation',
            description:
                'Les éléments envoyés par votre prestataire apparaîtront ici.',
          )
        else ...[
          Text(
            'Éléments à valider',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...sortedDeliverables.map((deliverable) {
            final version = _currentVersionFor(deliverable, versions);
            final canReview = deliverable.isAwaitingReview && version != null;
            return _ValidationTile(
              deliverable: deliverable,
              version: version,
              onApprove: canReview
                  ? () => _reviewDeliverable(
                      context,
                      ref,
                      deliverable,
                      version,
                      approved: true,
                    )
                  : null,
              onRequestChanges: canReview
                  ? () => _reviewDeliverable(
                      context,
                      ref,
                      deliverable,
                      version,
                      approved: false,
                    )
                  : null,
            );
          }),
        ],
      ],
    );
  }

  Future<void> _reviewDeliverable(
    BuildContext context,
    WidgetRef ref,
    DeliverableModel deliverable,
    DeliverableVersionModel version, {
    required bool approved,
  }) async {
    final service = ref.read(clientPortalServiceProvider);
    final comment = await showClientDeliverableReviewSheet(
      context: context,
      approved: approved,
    );
    if (comment == null) return;

    try {
      await service.reviewDeliverableVersion(
        deliverable: deliverable,
        version: version,
        approved: approved,
        comment: comment,
      );
    } catch (error) {
      // ignore: avoid_print
      print('[validation][client][review-error] $error');
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppTheme.borderColor(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
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

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events});

  final List<TimelineEventModel> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < events.length; index++)
            _TimelineRow(
              event: events[index],
              isLast: index == events.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final TimelineEventModel event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = event.isCompleted
        ? ClientPortalColors.cta
        : event.isCurrent
        ? ClientPortalColors.sage
        : AppTheme.secondaryTextColor(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              event.isCompleted
                  ? Icons.check_circle_rounded
                  : event.isCurrent
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: color,
              size: 22,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: AppTheme.borderColor(context),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
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
                if (event.date != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(event.date!),
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
        ),
      ],
    );
  }
}

class _ClientWorkTile extends StatelessWidget {
  const _ClientWorkTile({required this.action, this.onTap});

  final ClientActionModel action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final completed = action.status == 'completed';
    final color = completed ? ClientPortalColors.cta : ClientPortalColors.sage;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Row(
              children: [
                Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: TextStyle(
                          color: AppTheme.mainTextColor(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _actionSubtitle(action),
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.secondaryTextColor(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskStatusSummary extends StatelessWidget {
  const _TaskStatusSummary({required this.tasks});

  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    final todo = tasks.where((task) => task.status == 'À faire').length;
    final inProgress = tasks.where((task) => task.status == 'En cours').length;
    final done = tasks.where((task) => task.status == 'Terminé').length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TaskStatusPill(label: 'À faire', count: todo),
        _TaskStatusPill(label: 'En cours', count: inProgress),
        _TaskStatusPill(label: 'Terminées', count: done),
      ],
    );
  }
}

class _TaskStatusPill extends StatelessWidget {
  const _TaskStatusPill({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ClientPortalColors.softSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ClientPortalColors.border),
      ),
      child: Text(
        '$label $count',
        style: const TextStyle(
          color: ClientPortalColors.sage,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProjectTaskGroup extends StatelessWidget {
  const _ProjectTaskGroup({required this.projectTitle, required this.tasks});

  final String projectTitle;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            projectTitle,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...tasks.map((task) => _ClientTaskRow(task: task)),
        ],
      ),
    );
  }
}

class _ClientTaskRow extends StatelessWidget {
  const _ClientTaskRow({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'Terminé';
    final color = isDone ? ClientPortalColors.cta : ClientPortalColors.sage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isDone ? 'Terminé' : _taskDeadlineLabel(task.deadline),
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
    );
  }
}

class _ValidationTile extends StatelessWidget {
  const _ValidationTile({
    required this.deliverable,
    required this.version,
    this.onApprove,
    this.onRequestChanges,
  });

  final DeliverableModel deliverable;
  final DeliverableVersionModel? version;
  final VoidCallback? onApprove;
  final VoidCallback? onRequestChanges;

  @override
  Widget build(BuildContext context) {
    final color = _validationColor(deliverable.status);
    final fileName = version?.fileName ?? '';
    final versionSubtitle =
        'V${deliverable.currentVersion} • ${_validationLabel(deliverable.status)}'
        '${fileName.isEmpty ? '' : ' • $fileName'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.mainTextColor(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        versionSubtitle,
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.secondaryTextColor(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (version != null && version!.previewUrl.trim().isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => openValidationVersionFile(
                    context: context,
                    deliverable: deliverable,
                    version: version!,
                  ),
                  icon: Icon(
                    version!.externalUrl.trim().isNotEmpty &&
                            version!.storageUrl.trim().isEmpty
                        ? Icons.open_in_new_rounded
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(validationOpenLabel(version)),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Aucun fichier associé',
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (onApprove != null || onRequestChanges != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRequestChanges,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Valider'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabsHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 68;

  @override
  double get maxExtent => 68;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TabsHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

ProjectModel? _findProject(List<ProjectModel> projects, String projectId) {
  for (final project in projects) {
    if (project.id == projectId) return project;
  }
  return null;
}

TimelineEventModel? _nextTimelineStep(List<TimelineEventModel> events) {
  if (events.isEmpty) return null;
  final sorted = [...events]..sort((a, b) => a.order.compareTo(b.order));
  for (final event in sorted) {
    if (event.isCurrent) return event;
  }
  for (final event in sorted) {
    if (event.isUpcoming) return event;
  }
  return sorted.last;
}

DeliverableVersionModel? _currentVersionFor(
  DeliverableModel deliverable,
  List<DeliverableVersionModel> versions,
) {
  final matches =
      versions
          .where((version) => version.deliverableId == deliverable.id)
          .toList()
        ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
  return matches.isEmpty ? null : matches.first;
}

int _compareActions(ClientActionModel a, ClientActionModel b) {
  if (a.status != b.status) return a.status == 'pending' ? -1 : 1;
  final aDate = a.dueDate ?? DateTime(9999);
  final bDate = b.dueDate ?? DateTime(9999);
  final dateCompare = aDate.compareTo(bDate);
  if (dateCompare != 0) return dateCompare;
  return _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
}

int _compareTasks(TaskModel a, TaskModel b) {
  final statusCompare = _taskStatusRank(
    a.status,
  ).compareTo(_taskStatusRank(b.status));
  if (statusCompare != 0) return statusCompare;

  final aDate = _parseTaskDeadline(a.deadline);
  final bDate = _parseTaskDeadline(b.deadline);
  final dateCompare = (aDate ?? DateTime(9999)).compareTo(
    bDate ?? DateTime(9999),
  );
  if (dateCompare != 0) return dateCompare;

  return a.title.compareTo(b.title);
}

int _taskStatusRank(String status) {
  switch (status) {
    case 'À faire':
      return 0;
    case 'En cours':
      return 1;
    case 'Terminé':
      return 2;
    default:
      return 3;
  }
}

int _priorityRank(String priority) {
  switch (priority) {
    case 'high':
      return 0;
    case 'medium':
      return 1;
    default:
      return 2;
  }
}

DateTime? _parseTaskDeadline(String deadline) {
  final match = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
  ).firstMatch(deadline.trim());
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String _taskDeadlineLabel(String deadline) {
  if (deadline.trim().isEmpty) return 'Sans échéance';
  final date = _parseTaskDeadline(deadline);
  if (date == null) return deadline;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = day.difference(today).inDays;

  if (diff == 0) return 'Aujourd’hui';
  if (diff == 1) return 'Demain';
  if (diff < 0) return 'En retard';
  return deadline;
}

String _actionSubtitle(ClientActionModel action) {
  final status = action.status == 'completed' ? 'Terminé' : 'En cours';
  final due = action.dueDate == null
      ? ''
      : ' • ${_formatDate(action.dueDate!)}';
  return '$status • ${_priorityLabel(action.priority)}$due';
}

String _priorityLabel(String priority) {
  switch (priority) {
    case 'high':
      return 'Priorité haute';
    case 'low':
      return 'Priorité basse';
    default:
      return 'Priorité moyenne';
  }
}

String _validationLabel(String status) {
  switch (status) {
    case 'approved':
      return 'Validé';
    case 'changesRequested':
      return 'Modifications demandées';
    default:
      return 'À valider';
  }
}

Color _validationColor(String status) {
  switch (status) {
    case 'approved':
      return const Color(0xFF16A34A);
    case 'changesRequested':
      return const Color(0xFFDC2626);
    default:
      return ClientPortalColors.sage;
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

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

int _progressPercent(double progress) {
  return (_normalizedProgress(progress) * 100).round();
}

double _normalizedProgress(double progress) {
  final normalized = progress > 1 ? progress / 100 : progress;
  return normalized.clamp(0.0, 1.0);
}

void _openClientAction(
  BuildContext context,
  WidgetRef ref,
  ClientActionModel action,
) {
  if (action.type == 'document') {
    context.go('/client/documents');
    return;
  }
  if (action.type == 'validation') {
    context.go(_clientProjectValidationPath(action.projectId));
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.cardColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(action.title, style: Theme.of(context).textTheme.titleLarge),
              if (action.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  action.description,
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _completeClientAction(context, ref, action);
                  },
                  child: Text(_primaryButtonLabelForAction(action.type)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _clientProjectValidationPath(String projectId) {
  final encodedProjectId = Uri.encodeComponent(projectId);
  return '/client/projects/$encodedProjectId?tab=validations';
}

String _primaryButtonLabelForAction(String type) {
  switch (type) {
    case 'information':
      return 'Marquer comme lu';
    case 'task':
      return 'Marquer comme terminé';
    default:
      return 'Terminer l’action';
  }
}

Future<void> _completeClientAction(
  BuildContext context,
  WidgetRef ref,
  ClientActionModel action,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await ref
        .read(clientPortalServiceProvider)
        .completeCurrentClientAction(action);
    ref.invalidate(clientHomeActionsProvider);
    messenger?.showSnackBar(const SnackBar(content: Text('Action terminée.')));
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Impossible de terminer cette action.')),
    );
  }
}
