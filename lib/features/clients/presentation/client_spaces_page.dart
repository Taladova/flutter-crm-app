import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/french_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../data/models/client_model.dart';
import '../../projects/providers/project_providers.dart';
import '../providers/client_providers.dart';

/// Lists every client with their portal access status, and links to
/// [ClientSpaceDetailPage]/`/client-spaces/:clientId` to manage it. Reuses
/// the exact same client_invitations / client_accounts / shared_clients
/// logic as the client detail page's "Espace client" tab — no second portal
/// system.
class ClientSpacesPage extends ConsumerStatefulWidget {
  const ClientSpacesPage({super.key});

  @override
  ConsumerState<ClientSpacesPage> createState() => _ClientSpacesPageState();
}

class _ClientSpacesPageState extends ConsumerState<ClientSpacesPage> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<ClientModel> _filter(List<ClientModel> clients) {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return clients;
    return clients
        .where(
          (client) =>
              client.name.toLowerCase().contains(query) ||
              client.company.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientControllerProvider);
    final projects = ref.watch(projectControllerProvider).value ?? [];

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _Header(onBack: () => context.pop()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: AppSearchField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                hintText: 'Rechercher un client...',
              ),
            ),
            Expanded(
              child: clientsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: AppEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Erreur',
                    description: 'Impossible de charger vos clients.',
                    onRetry: () => ref.invalidate(clientControllerProvider),
                  ),
                ),
                data: (clients) {
                  final filtered = _filter(clients);

                  if (filtered.isEmpty) {
                    return Center(
                      child: AppEmptyState(
                        icon: clients.isEmpty
                            ? Icons.groups_outlined
                            : Icons.search_off_rounded,
                        title: clients.isEmpty
                            ? 'Aucun client'
                            : 'Aucun client trouvé',
                        description: clients.isEmpty
                            ? 'Ajoutez un client pour lui donner accès à son espace.'
                            : 'Essayez une autre recherche.',
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final client = filtered[index];
                      final projectsCount = projects
                          .where(
                            (project) =>
                                project.clientName.trim().toLowerCase() ==
                                client.name.trim().toLowerCase(),
                          )
                          .length;
                      return _ClientSpaceCard(
                        client: client,
                        projectsCount: projectsCount,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor(context)),
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
                'Portail client',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Espaces clients',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClientSpaceCard extends StatelessWidget {
  const _ClientSpaceCard({required this.client, required this.projectsCount});

  final ClientModel client;
  final int projectsCount;

  @override
  Widget build(BuildContext context) {
    final hasAccess = client.isShared;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/client-spaces/${client.id}'),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
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
                        : client.name.trim().substring(0, 1).toUpperCase(),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (client.company.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        client.company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      frPlural(projectsCount, 'projet', 'projets'),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (hasAccess
                                  ? AppTheme.primary(context)
                                  : AppTheme.secondaryTextColor(context))
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      hasAccess ? 'Accès actif' : 'Aucun accès',
                      style: TextStyle(
                        color: hasAccess
                            ? AppTheme.primary(context)
                            : AppTheme.secondaryTextColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.secondaryTextColor(context),
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
