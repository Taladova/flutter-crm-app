import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/task_model.dart';
import '../../clients/providers/client_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../../tasks/providers/task_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientControllerProvider);
    final projectsAsync = ref.watch(projectControllerProvider);
    final tasksAsync = ref.watch(taskControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashboardHeader(),
              const SizedBox(height: 28),
              _StatsGrid(
                clientsAsync: clientsAsync,
                projectsAsync: projectsAsync,
                tasksAsync: tasksAsync,
              ),
              const SizedBox(height: 28),
              SectionTitle(
                title: 'Projets récents',
                actionText: 'Voir tout',
                onActionTap: () {},
              ),
              const SizedBox(height: 14),
              _RecentProjectsList(projectsAsync: projectsAsync),
              const SizedBox(height: 28),
              SectionTitle(
                title: 'Tâches urgentes',
                actionText: 'Voir tout',
                onActionTap: () {},
              ),
              const SizedBox(height: 14),
              _UrgentTasksList(tasksAsync: tasksAsync),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bonjour 👋',
                style: TextStyle(
                  color: AppTheme.greyTextColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Votre activité',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppTheme.darkTextColor,
          ),
        ),
      ],
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
    final clientsCount = clientsAsync.value?.length ?? 0;
    final projects = projectsAsync.value ?? <ProjectModel>[];
    final tasks = tasksAsync.value ?? <TaskModel>[];

    final activeProjects = projects
        .where((project) => project.status == 'En cours')
        .length;

    final openTasks = tasks.where((task) => task.status != 'Terminé').length;

    final totalRevenue = projects.fold<double>(0, (sum, project) {
      final cleanBudget = project.budget
          .replaceAll('€', '')
          .replaceAll(' ', '')
          .replaceAll(',', '.');

      return sum + (double.tryParse(cleanBudget) ?? 0);
    });

    final stats = [
      _DashboardStat(
        title: 'Clients',
        value: '$clientsCount',
        icon: Icons.groups_rounded,
      ),
      _DashboardStat(
        title: 'Projets actifs',
        value: '$activeProjects',
        icon: Icons.work_rounded,
      ),
      _DashboardStat(
        title: 'Tâches ouvertes',
        value: '$openTasks',
        icon: Icons.checklist_rounded,
      ),
      _DashboardStat(
        title: 'Revenus estimés',
        value: '${(totalRevenue / 1000).toStringAsFixed(1)}k€',
        icon: Icons.payments_rounded,
      ),
    ];

    return GridView.builder(
      itemCount: stats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              stat.icon,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            stat.value,
            style: const TextStyle(
              color: AppTheme.darkTextColor,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.title,
            style: const TextStyle(
              color: AppTheme.greyTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentProjectsList extends StatelessWidget {
  const _RecentProjectsList({
    required this.projectsAsync,
  });

  final AsyncValue<List<ProjectModel>> projectsAsync;

  @override
  Widget build(BuildContext context) {
    return projectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Text('Erreur projets'),
      data: (projects) {
        final recentProjects = projects.take(3).toList();

        if (recentProjects.isEmpty) {
          return const AppCard(
            child: Text('Aucun projet récent'),
          );
        }

        return Column(
          children: recentProjects
              .map(
                (project) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ProjectCard(project: project),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
  });

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final percent = (project.progress * 100).round();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(
                  Icons.language_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: const TextStyle(
                        color: AppTheme.darkTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.clientName,
                      style: const TextStyle(
                        color: AppTheme.greyTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                project.budget,
                style: const TextStyle(
                  color: AppTheme.darkTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
                style: const TextStyle(
                  color: AppTheme.darkTextColor,
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

class _UrgentTasksList extends StatelessWidget {
  const _UrgentTasksList({
    required this.tasksAsync,
  });

  final AsyncValue<List<TaskModel>> tasksAsync;

  @override
  Widget build(BuildContext context) {
    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Text('Erreur tâches'),
      data: (tasks) {
        final urgentTasks =
            tasks.where((task) => task.status != 'Terminé').take(3).toList();

        if (urgentTasks.isEmpty) {
          return const AppCard(
            child: Text('Aucune tâche urgente'),
          );
        }

        return Column(
          children: urgentTasks
              .map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TaskTile(task: task),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
  });

  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.priority_high_rounded,
              color: Color(0xFFF97316),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.projectName,
                  style: const TextStyle(
                    color: AppTheme.greyTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            task.priority,
            style: const TextStyle(
              color: Color(0xFFF97316),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStat {
  const _DashboardStat({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}