import 'package:clientflow_pro/core/widgets/app_fade_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/models/client_model.dart';
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
    'Actif',
    'Prospect',
    'En attente',
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
          selectedFilter == 'Tous' || client.status == selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ClientsHeader(),
              const SizedBox(height: 24),
              _SearchField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
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
              const SectionTitle(title: 'Clients récents'),
              const SizedBox(height: 14),
              clientsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => const AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Erreur de chargement',
                  description:
                      'Impossible de charger les clients pour le moment.',
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
                              child: _ClientCard(client: client),
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
        GestureDetector(
          onTap: () {
            context.push('/clients/add');
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final fieldColor = AppTheme.isDark(context)
        ? const Color(0xFF000B27)
        : AppTheme.cardColor(context);

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        color: AppTheme.mainTextColor(context),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Rechercher un client...',
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppTheme.secondaryTextColor(context),
        ),
        filled: true,
        fillColor: fieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: TextStyle(
          color: AppTheme.secondaryTextColor(context),
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppTheme.borderColor(context),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppTheme.borderColor(context),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.5,
          ),
        ),
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

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client});

  final ClientModel client;

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
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.14),
                    child: Text(
                      client.name.substring(0, 1),
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
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
              const SizedBox(height: 18),
              _InfoRow(icon: Icons.email_rounded, text: client.email),
              const SizedBox(height: 10),
              _InfoRow(icon: Icons.phone_rounded, text: client.phone),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.isDark(context)
                      ? const Color(0xFF000B27)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.borderColor(context),
                  ),
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
                      '${client.projectsCount} projet(s) associé(s)',
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.secondaryTextColor(context),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}