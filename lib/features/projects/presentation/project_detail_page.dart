import 'package:clientflow_pro/core/widgets/app_empty_state.dart';
import 'package:clientflow_pro/data/models/task_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../data/models/project_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: project == null
            ? const Center(child: Text('Projet introuvable'))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProjectHeader(project: project),
                    const SizedBox(height: 24),
                    _ProjectHeroCard(
                      project: project,
                      percent: (project.progress * 100).round(),
                    ),
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
                        child: const Center(
                          child: Text(
                            'Ajouter une tâche',
                            style: TextStyle(
                              color: Colors.white,
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
                    const _ProjectNotesCard(),
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
          color: Colors.white,
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
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.greyTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.project});

  final ProjectModel project;

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
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.darkTextColor,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Détail projet',
                style: TextStyle(
                  color: AppTheme.greyTextColor,
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
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 21),
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
            color: AppTheme.primaryColor.withOpacity(0.22),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${project.clientName} • ${project.type}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
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
                    backgroundColor: Colors.white.withOpacity(0.22),
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Colors.white,
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
            style: const TextStyle(
              color: AppTheme.darkTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          item.date,
          style: const TextStyle(
            color: AppTheme.greyTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProjectNotesCard extends StatelessWidget {
  const _ProjectNotesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: const Text(
        'Projet WordPress à présenter comme une boutique premium. Prévoir une homepage claire, des fiches produits soignées, une expérience mobile fluide et une configuration WooCommerce propre.',
        style: TextStyle(
          color: AppTheme.greyTextColor,
          fontSize: 14,
          height: 1.6,
          fontWeight: FontWeight.w600,
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
        Icon(icon, color: AppTheme.greyTextColor, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label : ',
          style: const TextStyle(
            color: AppTheme.greyTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.darkTextColor,
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
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
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
        color: Colors.black.withOpacity(0.025),
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
