import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/currency_text.dart';
import '../../../core/utils/french_text.dart';
import '../../../core/widgets/app_header_icon_button.dart';
import '../../../core/widgets/app_notification_bell.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/models/client_action_model.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/document_request_model.dart';
import '../../../data/models/morning_brief_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/project_pulse_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../actions/providers/project_action_providers.dart';
import '../../clients/providers/client_providers.dart';
import '../providers/morning_brief_provider.dart';
import '../../projects/providers/project_pulse_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../../tasks/providers/task_providers.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({
    super.key,
    required this.pulseKey,
    required this.actionsKey,
    required this.openDrawer,
  });

  final GlobalKey pulseKey;
  final GlobalKey actionsKey;
  final VoidCallback openDrawer;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientControllerProvider);
    final projectsAsync = ref.watch(projectControllerProvider);
    final tasksAsync = ref.watch(taskControllerProvider);
    final actionsAsync = ref.watch(projectActionControllerProvider);

    final userName = ref.watch(userDisplayNameProvider).value ?? 'Utilisateur';

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(
                userName: userName,
                openDrawer: widget.openDrawer,
              ),
              const SizedBox(height: 20),
              _StatsGrid(
                clientsAsync: clientsAsync,
                projectsAsync: projectsAsync,
                tasksAsync: tasksAsync,
              ),
              const SizedBox(height: 20),
              _ProjectPulseDashboardCard(key: widget.pulseKey),
              const SizedBox(height: 20),
              _PriorityActionsSection(
                key: widget.actionsKey,
                actionsAsync: actionsAsync,
                clients: clientsAsync.value ?? const <ClientModel>[],
                projects: projectsAsync.value ?? const <ProjectModel>[],
              ),
              const SizedBox(height: 20),
              _UpcomingDeadlinesSection(
                projectsAsync: projectsAsync,
                tasks: tasksAsync.value ?? const <TaskModel>[],
                actions: actionsAsync.value ?? const <ClientActionModel>[],
              ),
              const SizedBox(height: 20),
              _ClientActivitySection(
                actionsAsync: actionsAsync,
                clients: clientsAsync.value ?? const <ClientModel>[],
                projects: projectsAsync.value ?? const <ProjectModel>[],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.userName, required this.openDrawer});

  final String userName;
  final VoidCallback openDrawer;

  @override
  Widget build(BuildContext context) {
    final initial = userName.trim().isEmpty
        ? '?'
        : userName.trim().characters.first.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppHeaderIconButton(
              icon: Icons.menu_rounded,
              tooltip: 'Ouvrir le menu',
              onTap: openDrawer,
            ),
            const Spacer(),
            const AppNotificationBell(portal: NotificationPortal.professional),
            const SizedBox(width: 10),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primary(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: AppTheme.primary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Bonjour $userName 👋',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Voici un aperçu de votre activité',
          style: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              color: AppTheme.secondarySurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.mainTextColor(context),
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
                const SizedBox(width: 12),
                Text(
                  badge,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
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

class MorningBriefCard extends ConsumerWidget {
  const MorningBriefCard({super.key, required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefState = ref.watch(morningBriefProvider);
    final projects = ref.watch(projectControllerProvider).value ?? [];

    return briefState.when(
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _dashboardCardDecoration(context),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) =>
          const _EmptyDashboardCard(text: 'Brief du jour indisponible'),
      data: (brief) {
        final visibleItems = _morningBriefItems(brief);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _dashboardCardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.wb_sunny_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour $userName',
                          style: TextStyle(
                            color: AppTheme.mainTextColor(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          brief.hasAttentionItems
                              ? 'Voici ce qui nécessite votre attention aujourd’hui.'
                              : 'Tout est calme pour aujourd’hui.',
                          style: TextStyle(
                            color: AppTheme.secondaryTextColor(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (visibleItems.isEmpty)
                _MorningBriefQuietState(onTap: () => context.go('/main?tab=1'))
              else ...[
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: visibleItems
                      .map(
                        (item) => _MorningBriefMetricChip(
                          item: item,
                          onTap: () =>
                              _openMorningBriefDetails(context, item, projects),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openAllPriorities(context, brief, projects),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Voir mes priorités'),
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

class _MorningBriefQuietState extends StatelessWidget {
  const _MorningBriefQuietState({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aucune priorité urgente. Vous pouvez consulter vos projets.',
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontWeight: FontWeight.w800,
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

class _MorningBriefMetricChip extends StatelessWidget {
  const _MorningBriefMetricChip({required this.item, required this.onTap});

  final _MorningBriefItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: item.color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: item.color, size: 18),
              const SizedBox(width: 8),
              Text(
                '${item.count}',
                style: TextStyle(
                  color: item.color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.clientsAsync,
    required this.projectsAsync,
    required this.tasksAsync,
  });

  final AsyncValue clientsAsync;
  final AsyncValue<List<ProjectModel>> projectsAsync;
  final AsyncValue<List<TaskModel>> tasksAsync;

  @override
  Widget build(BuildContext context) {
    final isLoading =
        (clientsAsync.isLoading && !clientsAsync.hasValue) ||
        (projectsAsync.isLoading && !projectsAsync.hasValue) ||
        (tasksAsync.isLoading && !tasksAsync.hasValue);

    final hasError =
        clientsAsync.hasError || projectsAsync.hasError || tasksAsync.hasError;

    if (isLoading) {
      return const _StatsLoadingGrid();
    }

    if (hasError) {
      return _StatsErrorCard(
        message:
            'Impossible de charger toutes les statistiques. Vérifiez les projets et les tâches.',
      );
    }

    final clientsCount = clientsAsync.value?.length ?? 0;
    final projects = projectsAsync.value ?? <ProjectModel>[];
    final tasks = tasksAsync.value ?? <TaskModel>[];

    final activeProjects = projects.where(_isActiveDashboardProject).length;
    final openTasks = tasks.where(_isOpenTask).length;
    final estimatedRevenue = projects
        .where(_isRevenueProject)
        .fold<double>(
          0,
          (total, project) => total + _parseBudgetAmount(project.budget),
        );

    final stats = [
      _DashboardStat(
        title: 'Clients actifs',
        subtitle: '',
        value: '$clientsCount',
        icon: Icons.groups_rounded,
        color: AppTheme.primary(context),
      ),
      _DashboardStat(
        title: 'Projets en cours',
        subtitle: '',
        value: '$activeProjects',
        icon: Icons.work_rounded,
        color: AppTheme.secondary(context),
      ),
      _DashboardStat(
        title: 'Tâches à traiter',
        subtitle: '',
        value: '$openTasks',
        icon: Icons.checklist_rounded,
        color: AppTheme.primary(context),
      ),
      _DashboardStat(
        title: 'Revenus estimés',
        subtitle: '',
        value: _formatRevenue(estimatedRevenue),
        icon: Icons.payments_rounded,
        color: AppTheme.accent(context),
      ),
    ];

    return GridView.builder(
      itemCount: stats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.62,
      ),
      itemBuilder: (context, index) {
        return _StatCard(stat: stats[index]);
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _DashboardStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? AppTheme.secondarySurface(context)
            : AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.65),
        ),
        boxShadow: [
          if (!AppTheme.isDark(context))
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(stat.icon, color: stat.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stat.value,
                    maxLines: 1,
                    style: TextStyle(
                      color: AppTheme.mainTextColor(context),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (stat.subtitle.isNotEmpty)
                  Text(
                    stat.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor(
                        context,
                      ).withValues(alpha: 0.78),
                      fontSize: 11,
                      height: 1.15,
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

class _StatsLoadingGrid extends StatelessWidget {
  const _StatsLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.46,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.secondarySurface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
        );
      },
    );
  }
}

class _StatsErrorCard extends StatelessWidget {
  const _StatsErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _dashboardCardDecoration(context),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppTheme.mainTextColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectPulseDashboardCard extends ConsumerWidget {
  const _ProjectPulseDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulseState = ref.watch(projectPulseDashboardProvider);
    final projects = ref.watch(projectControllerProvider).value ?? [];

    return pulseState.when(
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _dashboardCardDecoration(context),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const _EmptyDashboardCard(
        text: 'Impossible de calculer l’état des projets',
      ),
      data: (summary) {
        final attentionPulse =
            summary.byStatus(ProjectPulseStatus.needsAttention).isEmpty
            ? null
            : summary.byStatus(ProjectPulseStatus.needsAttention).first;
        final attentionProject = attentionPulse == null
            ? null
            : _findProject(projects, attentionPulse.projectId);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _dashboardCardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'État des projets',
                          style: TextStyle(
                            color: AppTheme.mainTextColor(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Vue d’ensemble de vos projets en cours',
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
                    Icons.monitor_heart_rounded,
                    color: AppTheme.primary(context),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _PulseSummaryChip(
                      label: 'En bonne voie',
                      value: summary.onTrack,
                      color: const Color(0xFF16A34A),
                      onTap: () => _showPulseProjects(
                        context,
                        projects,
                        summary.byStatus(ProjectPulseStatus.onTrack),
                        'Projets en bonne voie',
                      ),
                    ),
                  ),
                  Expanded(
                    child: _PulseSummaryChip(
                      label: 'En attente client',
                      value: summary.waitingClient,
                      color: const Color(0xFFD97706),
                      onTap: () => _showPulseProjects(
                        context,
                        projects,
                        summary.byStatus(ProjectPulseStatus.waitingClient),
                        'Projets en attente du client',
                      ),
                    ),
                  ),
                  Expanded(
                    child: _PulseSummaryChip(
                      label: 'À surveiller',
                      value: summary.needsAttention,
                      color: const Color(0xFFDC2626),
                      onTap: () => _showPulseProjects(
                        context,
                        projects,
                        summary.byStatus(ProjectPulseStatus.needsAttention),
                        'Projets à traiter',
                      ),
                    ),
                  ),
                ],
              ),
              if (attentionPulse != null && attentionProject != null) ...[
                const SizedBox(height: 14),
                _PulseAttentionTile(
                  pulse: attentionPulse,
                  project: attentionProject,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showPulseProjects(
    BuildContext context,
    List<ProjectModel> projects,
    List<ProjectPulseModel> pulses,
    String title,
  ) {
    final filteredProjects = pulses
        .map((pulse) => _findProject(projects, pulse.projectId))
        .whereType<ProjectModel>()
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
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
                Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 14),
                if (filteredProjects.isEmpty)
                  const _EmptyDashboardCard(text: 'Aucun projet dans ce filtre')
                else
                  ...filteredProjects.map(
                    (project) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PulseProjectTile(
                        project: project,
                        pulse: pulses.firstWhere(
                          (pulse) => pulse.projectId == project.id,
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          context.push('/projects/${project.id}');
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PulseAttentionTile extends StatelessWidget {
  const _PulseAttentionTile({required this.pulse, required this.project});

  final ProjectPulseModel pulse;
  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final blockedText = pulse.daysBlocked > 0
        ? 'Depuis ${frDays(pulse.daysBlocked)}'
        : pulse.reason;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/projects/${project.id}'),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFDC2626).withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.priority_high_rounded,
                color: Color(0xFFDC2626),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'À surveiller',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      blockedText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Voir',
                style: TextStyle(
                  color: AppTheme.primary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseSummaryChip extends StatelessWidget {
  const _PulseSummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseProjectTile extends StatelessWidget {
  const _PulseProjectTile({
    required this.project,
    required this.pulse,
    required this.onTap,
  });

  final ProjectModel project;
  final ProjectPulseModel pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _pulseStatusColor(pulse.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.secondarySurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor(context)),
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
                child: Icon(_pulseStatusIcon(pulse.status), color: color),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pulse.reason,
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
                '${(pulse.progress * 100).round()}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityActionsSection extends StatelessWidget {
  const _PriorityActionsSection({
    super.key,
    required this.actionsAsync,
    required this.clients,
    required this.projects,
  });

  final AsyncValue<List<ClientActionModel>> actionsAsync;
  final List<ClientModel> clients;
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    return actionsAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Actions prioritaires'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: _dashboardCardDecoration(context),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionTitle(title: 'Actions prioritaires'),
          SizedBox(height: 14),
          _EmptyDashboardCard(
            text: 'Impossible de charger les actions prioritaires',
          ),
        ],
      ),
      data: (actions) {
        final priorityActions = _sortedPriorityActions(actions);
        final visibleActions = priorityActions.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            priorityActions.length > 3
                ? SectionTitle(
                    title: 'Actions prioritaires',
                    actionText: 'Voir tout',
                    onActionTap: () => _showAllPriorityActions(
                      context,
                      priorityActions,
                      clients,
                      projects,
                    ),
                  )
                : SectionTitle(title: 'Actions prioritaires'),
            const SizedBox(height: 10),
            if (visibleActions.isEmpty)
              const _CompactSuccessEmptyState(
                icon: Icons.check_circle_rounded,
                title: 'Tout est à jour',
                subtitle: 'Aucune action ne nécessite votre attention.',
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: _dashboardCardDecoration(context),
                child: Column(
                  children: visibleActions
                      .map(
                        (action) => _PriorityActionTile(
                          action: action,
                          client: _findClient(clients, action.clientId),
                          project: _findProject(projects, action.projectId),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAllPriorityActions(
    BuildContext context,
    List<ClientActionModel> actions,
    List<ClientModel> clients,
    List<ProjectModel> projects,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
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
                Text(
                  'Toutes les actions prioritaires',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                ...actions.map(
                  (action) => _PriorityActionTile(
                    action: action,
                    client: _findClient(clients, action.clientId),
                    project: _findProject(projects, action.projectId),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PriorityActionTile extends StatelessWidget {
  const _PriorityActionTile({
    required this.action,
    required this.client,
    required this.project,
  });

  final ClientActionModel action;
  final ClientModel? client;
  final ProjectModel? project;

  @override
  Widget build(BuildContext context) {
    final overdueDays = _overdueDays(action);
    final isOverdue = overdueDays > 0;
    final color = isOverdue
        ? const Color(0xFFDC2626)
        : action.priority == 'high'
        ? const Color(0xFFD97706)
        : AppTheme.primaryColor;
    final icon = isOverdue
        ? Icons.warning_rounded
        : action.priority == 'high'
        ? Icons.priority_high_rounded
        : Icons.schedule_rounded;
    final clientName = client?.name ?? project?.clientName ?? 'Client';
    final projectName = project?.title ?? 'Projet';
    final deadline = action.dueDate == null
        ? 'Échéance non définie'
        : 'Échéance ${_formatDashboardDate(action.dueDate!)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: project == null
            ? null
            : () => context.push('/projects/${project!.id}'),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$clientName • $projectName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      overdueDays > 0
                          ? '$deadline • en retard depuis ${frDays(overdueDays)}'
                          : deadline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isOverdue
                            ? const Color(0xFFDC2626)
                            : AppTheme.secondaryTextColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.secondaryTextColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingDeadlinesSection extends StatelessWidget {
  const _UpcomingDeadlinesSection({
    required this.projectsAsync,
    required this.tasks,
    required this.actions,
  });

  final AsyncValue<List<ProjectModel>> projectsAsync;
  final List<TaskModel> tasks;
  final List<ClientActionModel> actions;

  @override
  Widget build(BuildContext context) {
    return projectsAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Échéances à venir'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: _dashboardCardDecoration(context),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionTitle(title: 'Échéances à venir'),
          SizedBox(height: 10),
          _EmptyDashboardCard(
            text: 'Impossible de charger les échéances à venir',
          ),
        ],
      ),
      data: (projects) {
        final deadlines = _buildUpcomingDeadlines(
          projects: projects,
          tasks: tasks,
          actions: actions,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              title: 'Échéances à venir',
              actionText: deadlines.length > 3 ? 'Voir tout' : null,
              onActionTap: deadlines.length > 3
                  ? () => context.go('/main?tab=2')
                  : null,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: _dashboardCardDecoration(context),
              child: deadlines.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            color: AppTheme.secondaryTextColor(context),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Aucune échéance à venir pour le moment.',
                              style: TextStyle(
                                color: AppTheme.secondaryTextColor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: deadlines
                          .take(3)
                          .map(
                            (deadline) =>
                                _UpcomingDeadlineTile(deadline: deadline),
                          )
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _UpcomingDeadlineTile extends StatelessWidget {
  const _UpcomingDeadlineTile({required this.deadline});

  final _DashboardDeadline deadline;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(deadline.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(deadline.icon, color: AppTheme.primary(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deadline.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      deadline.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDashboardDate(deadline.date),
                style: TextStyle(
                  color: AppTheme.mainTextColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientActivitySection extends StatelessWidget {
  const _ClientActivitySection({
    required this.actionsAsync,
    required this.clients,
    required this.projects,
  });

  final AsyncValue<List<ClientActionModel>> actionsAsync;
  final List<ClientModel> clients;
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    return actionsAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Activité client'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: _dashboardCardDecoration(context),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionTitle(title: 'Activité client'),
          SizedBox(height: 14),
          _EmptyDashboardCard(text: 'Impossible de charger l’activité client'),
        ],
      ),
      data: (actions) {
        final activities = actions
            .where(
              (action) =>
                  action.assignedTo == 'client' &&
                  action.type == 'validation' &&
                  action.status == 'completed',
            )
            .toList();
        activities.sort((a, b) {
          final aDate = a.completedAt ?? a.updatedAt ?? DateTime(1900);
          final bDate = b.completedAt ?? b.updatedAt ?? DateTime(1900);
          return bDate.compareTo(aDate);
        });
        final visibleActivities = activities.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(title: 'Activité client'),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: _dashboardCardDecoration(context),
              child: visibleActivities.isEmpty
                  ? const _ClientActivityEmptyState()
                  : Column(
                      children: visibleActivities
                          .map(
                            (action) => _ClientActivityTile(
                              action: action,
                              client: _findClient(clients, action.clientId),
                              project: _findProject(projects, action.projectId),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ClientActivityTile extends StatelessWidget {
  const _ClientActivityTile({
    required this.action,
    required this.client,
    required this.project,
  });

  final ClientActionModel action;
  final ClientModel? client;
  final ProjectModel? project;

  @override
  Widget build(BuildContext context) {
    final date = action.completedAt ?? action.updatedAt;
    final clientName = client?.name ?? project?.clientName ?? 'Client';
    final projectName = project?.title ?? 'Projet';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF16A34A),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$projectName • ${_clientActivityLabel(action)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _relativeDashboardTime(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor(
                        context,
                      ).withValues(alpha: 0.78),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientActivityEmptyState extends StatelessWidget {
  const _ClientActivityEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: AppTheme.primaryColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aucune activité client récente. Les validations réelles apparaîtront ici dès qu’un client termine une action.',
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSuccessEmptyState extends StatelessWidget {
  const _CompactSuccessEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _dashboardCardDecoration(context),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary(context).withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppTheme.primary(context), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontSize: 11,
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

class _EmptyDashboardCard extends StatelessWidget {
  const _EmptyDashboardCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.secondaryTextColor(context),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

List<ClientActionModel> _sortedPriorityActions(
  List<ClientActionModel> actions,
) {
  final pendingActions = actions
      .where((action) => action.status == 'pending')
      .toList();

  pendingActions.sort((a, b) {
    final overdueCompare = _overdueDays(b).compareTo(_overdueDays(a));
    if (overdueCompare != 0) return overdueCompare;

    final priorityCompare = _actionPriorityRank(
      b.priority,
    ).compareTo(_actionPriorityRank(a.priority));
    if (priorityCompare != 0) return priorityCompare;

    final aDate = a.dueDate ?? DateTime(9999);
    final bDate = b.dueDate ?? DateTime(9999);
    final dateCompare = aDate.compareTo(bDate);
    if (dateCompare != 0) return dateCompare;

    return a.title.compareTo(b.title);
  });

  return pendingActions;
}

int _overdueDays(ClientActionModel action) {
  final dueDate = action.dueDate;
  if (dueDate == null) return 0;

  final today = _dateOnly(DateTime.now());
  final dueDay = _dateOnly(dueDate);
  if (!dueDay.isBefore(today)) return 0;
  return today.difference(dueDay).inDays;
}

String _assignedToDashboardLabel(String assignedTo) {
  return assignedTo == 'client' ? 'en attente client' : 'à faire par moi';
}

int _actionPriorityRank(String priority) {
  switch (priority) {
    case 'high':
      return 3;
    case 'medium':
      return 2;
    case 'low':
      return 1;
    default:
      return 0;
  }
}

String _formatDashboardDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}';
}

String _relativeDashboardTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  return 'il y a ${diff.inDays} jours';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime? _parseDashboardDate(String value) {
  final text = value.trim().toLowerCase();
  if (text.isEmpty) return null;

  final numericMatch = RegExp(
    r'^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$',
  ).firstMatch(text);
  if (numericMatch != null) {
    final day = int.tryParse(numericMatch.group(1)!);
    final month = int.tryParse(numericMatch.group(2)!);
    final rawYear = int.tryParse(numericMatch.group(3)!);
    if (day == null || month == null || rawYear == null) return null;
    final year = rawYear < 100 ? 2000 + rawYear : rawYear;
    return _safeDashboardDate(year, month, day);
  }

  final textMatch = RegExp(
    r'^(\d{1,2})\s+([a-zéû\.]+)\s+(\d{4})$',
  ).firstMatch(text);
  if (textMatch == null) return null;

  final month = _frenchMonthNumber(textMatch.group(2)!);
  final day = int.tryParse(textMatch.group(1)!);
  final year = int.tryParse(textMatch.group(3)!);
  if (day == null || month == null || year == null) return null;

  return _safeDashboardDate(year, month, day);
}

DateTime? _safeDashboardDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

int? _frenchMonthNumber(String month) {
  final normalized = month.replaceAll('.', '');
  const months = {
    'janvier': 1,
    'janv': 1,
    'février': 2,
    'fevrier': 2,
    'févr': 2,
    'fevr': 2,
    'mars': 3,
    'avril': 4,
    'avr': 4,
    'mai': 5,
    'juin': 6,
    'juillet': 7,
    'juil': 7,
    'août': 8,
    'aout': 8,
    'septembre': 9,
    'sept': 9,
    'octobre': 10,
    'oct': 10,
    'novembre': 11,
    'nov': 11,
    'décembre': 12,
    'decembre': 12,
    'déc': 12,
    'dec': 12,
  };
  return months[normalized];
}

List<_MorningBriefItem> _morningBriefItems(MorningBriefModel brief) {
  return [
    _MorningBriefItem(
      kind: _MorningBriefMetricKind.needsAttentionProjects,
      count: brief.needsAttentionProjectsCount,
      label: _plural(
        brief.needsAttentionProjectsCount,
        'projet à traiter',
        'projets à traiter',
      ),
      icon: Icons.priority_high_rounded,
      color: const Color(0xFFDC2626),
      items: brief.needsAttentionProjects,
    ),
    _MorningBriefItem(
      kind: _MorningBriefMetricKind.overdueActions,
      count: brief.overdueActionsCount,
      label: _plural(
        brief.overdueActionsCount,
        'action en retard',
        'actions en retard',
      ),
      icon: Icons.schedule_rounded,
      color: const Color(0xFFB91C1C),
      items: brief.overdueActions,
    ),
    _MorningBriefItem(
      kind: _MorningBriefMetricKind.waitingValidations,
      count: brief.waitingValidationsCount,
      label: _plural(
        brief.waitingValidationsCount,
        'validation client',
        'validations clients',
      ),
      icon: Icons.verified_rounded,
      color: const Color(0xFF7C3AED),
      items: brief.waitingValidations,
    ),
    _MorningBriefItem(
      kind: _MorningBriefMetricKind.receivedDocuments,
      count: brief.receivedDocumentsCount,
      label: _plural(
        brief.receivedDocumentsCount,
        'document reçu',
        'documents reçus',
      ),
      icon: Icons.folder_rounded,
      color: const Color(0xFF2563EB),
      items: brief.receivedDocuments,
    ),
    _MorningBriefItem(
      kind: _MorningBriefMetricKind.todayTasks,
      count: brief.todayTasksCount,
      label: _plural(
        brief.todayTasksCount,
        'tâche aujourd’hui',
        'tâches aujourd’hui',
      ),
      icon: Icons.task_alt_rounded,
      color: AppTheme.primaryColor,
      items: brief.todayTasks,
    ),
    _MorningBriefItem(
      kind: _MorningBriefMetricKind.pendingClientActions,
      count: brief.pendingClientActionsCount,
      label: _plural(
        brief.pendingClientActionsCount,
        'action côté client',
        'actions côté client',
      ),
      icon: Icons.person_pin_circle_rounded,
      color: const Color(0xFFD97706),
      items: brief.pendingClientActions,
    ),
  ].where((item) => item.count > 0).take(5).toList();
}

String _plural(int count, String singular, String plural) {
  return count <= 1 ? singular : plural;
}

void _openAllPriorities(
  BuildContext context,
  MorningBriefModel brief,
  List<ProjectModel> projects,
) {
  final items = _morningBriefItems(brief);
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.cardColor(context),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
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
              Text(
                'Priorités du jour',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MorningBriefPriorityTile(
                    item: item,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openMorningBriefDetails(context, item, projects);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _openMorningBriefDetails(
  BuildContext context,
  _MorningBriefItem item,
  List<ProjectModel> projects,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.cardColor(context),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
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
              Text(
                item.title,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              if (item.items.isEmpty)
                const _EmptyDashboardCard(text: 'Aucun élément dans ce filtre')
              else
                ...item.items
                    .take(8)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MorningBriefDetailTile(
                          entry: entry,
                          projects: projects,
                          onTap: () {
                            final route = _routeForMorningBriefEntry(entry);
                            if (route == null) return;
                            Navigator.pop(sheetContext);
                            context.push(route);
                          },
                        ),
                      ),
                    ),
            ],
          ),
        ),
      );
    },
  );
}

String? _routeForMorningBriefEntry(Object entry) {
  if (entry is ProjectModel) return '/projects/${entry.id}';
  if (entry is TaskModel) return '/tasks/${entry.id}';
  if (entry is ClientActionModel) return '/projects/${entry.projectId}';
  if (entry is DocumentRequestModel) return '/projects/${entry.projectId}';
  return null;
}

class _MorningBriefPriorityTile extends StatelessWidget {
  const _MorningBriefPriorityTile({required this.item, required this.onTap});

  final _MorningBriefItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NotificationTile(
      title: item.title,
      subtitle: frPlural(item.count, 'élément', 'éléments'),
      badge: 'Voir',
      onTap: onTap,
    );
  }
}

class _MorningBriefDetailTile extends StatelessWidget {
  const _MorningBriefDetailTile({
    required this.entry,
    required this.projects,
    required this.onTap,
  });

  final Object entry;
  final List<ProjectModel> projects;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _morningBriefEntryTitle(entry);
    final subtitle = _morningBriefEntrySubtitle(entry, projects);
    final route = _routeForMorningBriefEntry(entry);

    return _NotificationTile(
      title: title,
      subtitle: subtitle,
      badge: route == null ? '' : 'Ouvrir',
      onTap: route == null ? () {} : onTap,
    );
  }
}

String _morningBriefEntryTitle(Object entry) {
  if (entry is ProjectModel) return entry.title;
  if (entry is TaskModel) return entry.title;
  if (entry is ClientActionModel) return entry.title;
  if (entry is DocumentRequestModel) return entry.title;
  return 'Élément';
}

String _morningBriefEntrySubtitle(Object entry, List<ProjectModel> projects) {
  if (entry is ProjectModel) {
    return '${entry.clientName} • ${(entry.progress * 100).round()}%';
  }
  if (entry is TaskModel) {
    return '${entry.projectName} • ${entry.deadline}';
  }
  if (entry is ClientActionModel) {
    final project = _findProject(projects, entry.projectId);
    final dueDate = entry.dueDate == null
        ? ''
        : ' • ${_formatDashboardDate(entry.dueDate!)}';
    return '${project?.title ?? 'Projet'} • ${_assignedToDashboardLabel(entry.assignedTo)}$dueDate';
  }
  if (entry is DocumentRequestModel) {
    final project = _findProject(projects, entry.projectId);
    return '${project?.title ?? 'Projet'} • document reçu';
  }
  return '';
}

enum _MorningBriefMetricKind {
  needsAttentionProjects,
  overdueActions,
  pendingClientActions,
  receivedDocuments,
  todayTasks,
  waitingValidations,
}

class _MorningBriefItem {
  const _MorningBriefItem({
    required this.kind,
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
  });

  final _MorningBriefMetricKind kind;
  final int count;
  final String label;
  final IconData icon;
  final Color color;
  final List<Object> items;

  String get title {
    switch (kind) {
      case _MorningBriefMetricKind.needsAttentionProjects:
        return 'Projets à traiter';
      case _MorningBriefMetricKind.overdueActions:
        return 'Actions en retard';
      case _MorningBriefMetricKind.pendingClientActions:
        return 'Actions côté client';
      case _MorningBriefMetricKind.receivedDocuments:
        return 'Documents reçus';
      case _MorningBriefMetricKind.todayTasks:
        return 'Tâches prévues aujourd’hui';
      case _MorningBriefMetricKind.waitingValidations:
        return 'Validations en attente';
    }
  }
}

ProjectModel? _findProject(List<ProjectModel> projects, String projectId) {
  for (final project in projects) {
    if (project.id == projectId) return project;
  }
  return null;
}

ClientModel? _findClient(List<ClientModel> clients, String clientId) {
  for (final client in clients) {
    if (client.id == clientId) return client;
  }
  return null;
}

List<_DashboardDeadline> _buildUpcomingDeadlines({
  required List<ProjectModel> projects,
  required List<TaskModel> tasks,
  required List<ClientActionModel> actions,
}) {
  final today = _dateOnly(DateTime.now());
  final deadlines = <_DashboardDeadline>[];

  for (final project in projects.where(_isActiveDashboardProject)) {
    final date = _parseDashboardDate(project.deadline);
    if (date == null || date.isBefore(today)) continue;
    deadlines.add(
      _DashboardDeadline(
        title: project.title,
        subtitle: '${project.clientName} • Projet',
        date: date,
        route: '/projects/${project.id}',
        icon: Icons.work_rounded,
      ),
    );
  }

  for (final task in tasks.where(_isOpenTask)) {
    final date = _parseDashboardDate(task.deadline);
    if (date == null || date.isBefore(today)) continue;
    deadlines.add(
      _DashboardDeadline(
        title: task.title,
        subtitle: '${task.projectName} • Tâche',
        date: date,
        route: '/tasks/${task.id}',
        icon: Icons.check_circle_outline_rounded,
      ),
    );
  }

  for (final action in actions.where((action) => action.status == 'pending')) {
    final date = action.dueDate;
    if (date == null || _dateOnly(date).isBefore(today)) continue;
    deadlines.add(
      _DashboardDeadline(
        title: action.title,
        subtitle: '${_assignedToDashboardLabel(action.assignedTo)} • Action',
        date: date,
        route: '/projects/${action.projectId}',
        icon: Icons.flag_rounded,
      ),
    );
  }

  deadlines.sort((a, b) {
    final dateCompare = a.date.compareTo(b.date);
    if (dateCompare != 0) return dateCompare;
    return a.title.compareTo(b.title);
  });

  return deadlines;
}

String _clientActivityLabel(ClientActionModel action) {
  if (action.type == 'validation') return 'Validation : ${action.title}';
  if (action.type == 'document') return 'Document : ${action.title}';
  return action.title;
}

IconData _pulseStatusIcon(ProjectPulseStatus status) {
  switch (status) {
    case ProjectPulseStatus.onTrack:
      return Icons.trending_up_rounded;
    case ProjectPulseStatus.waitingClient:
      return Icons.hourglass_top_rounded;
    case ProjectPulseStatus.needsAttention:
      return Icons.priority_high_rounded;
    case ProjectPulseStatus.completed:
      return Icons.verified_rounded;
  }
}

Color _pulseStatusColor(ProjectPulseStatus status) {
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

BoxDecoration _dashboardCardDecoration(BuildContext context) {
  return BoxDecoration(
    color: AppTheme.cardColor(context),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppTheme.borderColor(context)),
    boxShadow: [
      if (!AppTheme.isDark(context))
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
    ],
  );
}

class _DashboardStat {
  const _DashboardStat({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;
}

class _DashboardDeadline {
  const _DashboardDeadline({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.route,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final DateTime date;
  final String route;
  final IconData icon;
}

bool _isActiveDashboardProject(ProjectModel project) {
  final status = project.status.trim().toLowerCase();
  return status != 'terminé' &&
      status != 'termine' &&
      status != 'en pause' &&
      status != 'pause' &&
      status != 'annulé' &&
      status != 'annule' &&
      status != 'archivé' &&
      status != 'archive';
}

bool _isRevenueProject(ProjectModel project) {
  final status = project.status.trim().toLowerCase();
  return status != 'annulé' &&
      status != 'annule' &&
      status != 'archivé' &&
      status != 'archive';
}

bool _isOpenTask(TaskModel task) {
  final status = task.status.trim().toLowerCase();
  return status != 'terminé' &&
      status != 'termine' &&
      status != 'annulé' &&
      status != 'annule' &&
      status != 'archivé' &&
      status != 'archive';
}

double _parseBudgetAmount(String budget) {
  final normalized = budget
      .toLowerCase()
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^0-9.k]'), '');
  if (normalized.isEmpty) return 0;

  final multiplier = normalized.contains('k') ? 1000 : 1;
  final number = double.tryParse(normalized.replaceAll('k', '')) ?? 0;
  return number * multiplier;
}

String _formatRevenue(double amount) {
  return formatCurrencyAmount(amount);
}
