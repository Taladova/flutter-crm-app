import 'package:clientflow_pro/core/widgets/app_fade_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/french_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_filter_tabs.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../data/models/client_model.dart';
import '../../projects/providers/project_providers.dart';
import '../providers/client_providers.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final TextEditingController searchController = TextEditingController();
  String selectedFilter = 'Tous';

  final List<String> filters = const [
    'Tous',
    'Actifs',
    'En attente',
    'Prospects',
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<ClientModel> filterClients(List<ClientModel> clients) {
    final query = searchController.text.toLowerCase();

    return clients.where((client) {
      final matchesSearch =
          client.name.toLowerCase().contains(query) ||
          client.company.toLowerCase().contains(query) ||
          client.email.toLowerCase().contains(query);

      final matchesFilter =
          selectedFilter == 'Tous' ||
          client.status == _statusValue(selectedFilter);

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Map<String, int> _statusCounts(List<ClientModel> clients) {
    return {
      'Tous': clients.length,
      'Actifs': clients.where((client) => client.status == 'Actif').length,
      'En attente': clients
          .where((client) => client.status == 'En attente')
          .length,
      'Prospects': clients
          .where((client) => client.status == 'Prospect')
          .length,
    };
  }

  String _statusValue(String filter) {
    return switch (filter) {
      'Actifs' => 'Actif',
      'Prospects' => 'Prospect',
      _ => filter,
    };
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientControllerProvider);
    final projects = ref.watch(projectControllerProvider).value ?? [];
    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-client-fab',
        tooltip: 'Ajouter un client',
        onPressed: () => context.push('/clients/add'),
        backgroundColor: AppTheme.primary(context),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ClientsHeader(),
              const SizedBox(height: 20),
              _ClientsSearchField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              clientsAsync.when(
                loading: () => AppFilterTabs(
                  labels: filters,
                  selectedLabel: selectedFilter,
                  onSelected: (filter) {
                    setState(() {
                      selectedFilter = filter;
                    });
                  },
                ),
                error: (_, _) => AppFilterTabs(
                  labels: filters,
                  selectedLabel: selectedFilter,
                  onSelected: (filter) {
                    setState(() {
                      selectedFilter = filter;
                    });
                  },
                ),
                data: (clients) => AppFilterTabs(
                  labels: filters,
                  selectedLabel: selectedFilter,
                  counts: _statusCounts(clients),
                  onSelected: (filter) {
                    setState(() {
                      selectedFilter = filter;
                    });
                  },
                ),
              ),
              const SizedBox(height: 22),
              _ClientsListSummary(
                clients: clientsAsync.value ?? const <ClientModel>[],
              ),
              const SizedBox(height: 14),
              clientsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Erreur de chargement',
                  description:
                      'Impossible de charger les clients pour le moment.',
                  onRetry: () => ref.invalidate(clientControllerProvider),
                ),
                data: (clients) {
                  final filteredClients = filterClients(clients);

                  if (filteredClients.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucun client trouvé',
                      description:
                          'Essayez une autre recherche ou un autre filtre.',
                    );
                  }

                  return Column(
                    children: filteredClients
                        .map(
                          (client) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppFadeIn(
                              delay: 100 * filteredClients.indexOf(client),
                              child: _ClientCard(
                                client: client,
                                projectsCount: projects
                                    .where(
                                      (project) =>
                                          project.clientName
                                              .trim()
                                              .toLowerCase() ==
                                          client.name.trim().toLowerCase(),
                                    )
                                    .length,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientsHeader extends StatelessWidget {
  const _ClientsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestion clients',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Vos clients',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClientsSearchField extends StatelessWidget {
  const _ClientsSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(
        color: AppTheme.mainTextColor(context),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Rechercher un client ou une entreprise…',
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: AppTheme.secondaryTextColor(context),
        ),
        suffixIcon: hasText
            ? IconButton(
                tooltip: 'Effacer la recherche',
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppTheme.secondaryTextColor(context),
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: AppTheme.isDark(context)
            ? AppTheme.secondarySurface(context)
            : AppTheme.secondarySurface(context).withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: TextStyle(
          color: AppTheme.secondaryTextColor(context).withValues(alpha: 0.82),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppTheme.borderColor(context).withValues(alpha: 0.55),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppTheme.borderColor(context).withValues(alpha: 0.55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppTheme.primary(context).withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _ClientsListSummary extends StatelessWidget {
  const _ClientsListSummary({required this.clients});

  final List<ClientModel> clients;

  @override
  Widget build(BuildContext context) {
    final activeCount = clients
        .where((client) => client.status.trim().toLowerCase() == 'actif')
        .length;
    final clientsLabel = frPlural(clients.length, 'client', 'clients');
    final activeLabel = frPlural(activeCount, 'actif', 'actifs');

    return Text(
      '$clientsLabel • $activeLabel',
      style: TextStyle(
        color: AppTheme.secondaryTextColor(context),
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.projectsCount});

  final ClientModel client;
  final int projectsCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          context.push('/clients/${client.id}');
        },
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        client.name.trim().isEmpty
                            ? '?'
                            : client.name.trim().substring(0, 1),
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: TextStyle(
                            color: AppTheme.mainTextColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          client.company,
                          style: TextStyle(
                            color: AppTheme.secondaryTextColor(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppStatusBadge(status: client.status),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.secondarySurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.work_rounded,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      frPlural(
                        projectsCount,
                        'projet associé',
                        'projets associés',
                      ),
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppTheme.secondaryTextColor(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
