import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_fade_in.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/models/task_model.dart';
import '../providers/task_providers.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  String selectedFilter = 'Toutes';

  final List<String> filters = const [
    'Toutes',
    'À faire',
    'En cours',
    'Terminé',
  ];

  List<TaskModel> filterTasks(List<TaskModel> tasks) {
    return tasks.where((task) {
      return selectedFilter == 'Toutes' || task.status == selectedFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(taskControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: tasksAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => Center(
            child: Text(
              'Erreur de chargement des tâches',
              style: TextStyle(
                color: AppTheme.mainTextColor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          data: (tasks) {
            final filteredTasks = filterTasks(tasks);
            final totalTasks = tasks.length;
            final doneTasks =
                tasks.where((task) => task.status == 'Terminé').length;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TasksHeader(),
                  const SizedBox(height: 24),
                  _TasksSummaryCard(
                    totalTasks: totalTasks,
                    doneTasks: doneTasks,
                  ),
                  const SizedBox(height: 24),
                  _FilterChips(
                    filters: filters,
                    selectedFilter: selectedFilter,
                    onFilterSelected: (filter) {
                      setState(() {
                        selectedFilter = filter;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle(title: 'Liste des tâches'),
                  const SizedBox(height: 14),
                  if (filteredTasks.isEmpty)
                    const AppEmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'Aucune tâche trouvée',
                      description:
                          'Essayez un autre filtre pour afficher vos tâches.',
                    )
                  else
                    Column(
                      children: filteredTasks
                          .map(
                            (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppFadeIn(
                                delay: 100 * filteredTasks.indexOf(task),
                                child: _TaskCard(
                                  task: task,
                                  onToggle: () {
                                    ref
                                        .read(taskControllerProvider.notifier)
                                        .toggleTaskStatus(task);
                                  },
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TasksHeader extends StatelessWidget {
  const _TasksHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organisation',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Vos tâches',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            context.push('/tasks/add');
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!AppTheme.isDark(context))
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _TasksSummaryCard extends StatelessWidget {
  const _TasksSummaryCard({
    required this.totalTasks,
    required this.doneTasks,
  });

  final int totalTasks;
  final int doneTasks;

  @override
  Widget build(BuildContext context) {
    final progress = totalTasks == 0 ? 0.0 : doneTasks / totalTasks;
    final percent = (progress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(26),
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.checklist_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progression globale',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$doneTasks tâche(s) terminée(s) sur $totalTasks • $percent%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: Colors.black.withOpacity(0.16),
                    color: Colors.white,
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filters,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter == selectedFilter;

          return GestureDetector(
            onTap: () => onFilterSelected(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor(context),
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.secondaryTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onToggle,
  });

  final TaskModel task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'Terminé';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onToggle,
        child: AppCard(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFFDCFCE7)
                      : AppTheme.primaryColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : Icons.radio_button_unchecked,
                  color:
                      isDone ? const Color(0xFF16A34A) : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        decoration: isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.projectName,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MiniBadge(
                          label: task.status,
                          type: 'status',
                        ),
                        const SizedBox(width: 8),
                        _MiniBadge(
                          label: task.priority,
                          type: 'priority',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 18,
                    color: AppTheme.secondaryTextColor(context),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task.deadline,
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.type,
  });

  final String label;
  final String type;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    if (type == 'priority') {
      switch (label) {
        case 'Haute':
          backgroundColor = const Color(0xFFFEE2E2);
          textColor = const Color(0xFFDC2626);
          break;
        case 'Moyenne':
          backgroundColor = const Color(0xFFFEF3C7);
          textColor = const Color(0xFFD97706);
          break;
        default:
          backgroundColor = AppTheme.primaryColor.withOpacity(0.14);
          textColor = AppTheme.primaryColor;
      }
    } else {
      switch (label) {
        case 'Terminé':
          backgroundColor = const Color(0xFFDCFCE7);
          textColor = const Color(0xFF16A34A);
          break;
        case 'En cours':
          backgroundColor = AppTheme.primaryColor.withOpacity(0.14);
          textColor = AppTheme.primaryColor;
          break;
        default:
          backgroundColor = AppTheme.isDark(context)
              ? const Color(0xFF000B27)
              : const Color(0xFFF1F5F9);
          textColor = AppTheme.secondaryTextColor(context);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: AppTheme.isDark(context)
              ? AppTheme.borderColor(context).withOpacity(0.45)
              : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}