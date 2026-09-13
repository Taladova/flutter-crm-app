import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_filter_tabs.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../data/models/client_message_model.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/project_model.dart';
import '../../clients/providers/client_providers.dart';
import '../../projects/providers/project_providers.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  final searchController = TextEditingController();
  String selectedFilter = 'Tous';

  static const filters = ['Tous', 'Non lus'];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientControllerProvider);
    final projects = ref.watch(projectControllerProvider).value ?? [];

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: clientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: AppEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Messages indisponibles',
              description:
                  'Impossible de charger vos conversations pour le moment.',
              onRetry: () => ref.invalidate(clientControllerProvider),
            ),
          ),
          data: (clients) {
            final conversations = _buildConversations(clients, projects);
            final visibleConversations = _filterConversations(conversations);

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Messages',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Toutes vos conversations clients au même endroit.',
                          style: TextStyle(
                            color: AppTheme.secondaryTextColor(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        AppSearchField(
                          controller: searchController,
                          onChanged: (_) => setState(() {}),
                          hintText: 'Rechercher une conversation…',
                        ),
                        const SizedBox(height: 14),
                        AppFilterTabs(
                          labels: filters,
                          selectedLabel: selectedFilter,
                          onSelected: (filter) {
                            setState(() => selectedFilter = filter);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (conversations.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 36, 20, 120),
                      child: AppEmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Aucune conversation',
                        description:
                            'Vos échanges avec vos clients apparaîtront ici.',
                      ),
                    ),
                  )
                else if (selectedFilter == 'Non lus')
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 36, 20, 120),
                      child: AppEmptyState(
                        icon: Icons.mark_chat_unread_outlined,
                        title: 'Non-lus indisponibles',
                        description:
                            'Le suivi de lecture n’est pas encore disponible.',
                      ),
                    ),
                  )
                else if (visibleConversations.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 36, 20, 120),
                      child: AppEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Aucune conversation trouvée',
                        description: 'Essayez avec un autre client ou projet.',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
                    sliver: SliverList.separated(
                      itemCount: visibleConversations.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: AppTheme.borderColor(context),
                        indent: 58,
                      ),
                      itemBuilder: (context, index) {
                        return _ConversationListItem(
                          conversation: visibleConversations[index],
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_ConversationPreview> _buildConversations(
    List<ClientModel> clients,
    List<ProjectModel> projects,
  ) {
    final sharedClients = clients.where((client) => client.isShared).toList();
    final conversations = sharedClients.map((client) {
      final project = _projectForClient(client, projects);
      final lastMessage = ref
          .watch(clientLastMessageProvider(client.shareToken))
          .asData
          ?.value;
      return _ConversationPreview(
        client: client,
        project: project,
        lastMessage: lastMessage,
      );
    }).toList();

    conversations.sort((a, b) {
      final aDate = a.lastMessage?.createdAt;
      final bDate = b.lastMessage?.createdAt;
      if (aDate == null && bDate == null) {
        return a.client.name.compareTo(b.client.name);
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return conversations;
  }

  List<_ConversationPreview> _filterConversations(
    List<_ConversationPreview> conversations,
  ) {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return conversations;

    return conversations.where((conversation) {
      final lastText = conversation.lastMessage?.text.toLowerCase() ?? '';
      return conversation.client.name.toLowerCase().contains(query) ||
          conversation.client.company.toLowerCase().contains(query) ||
          (conversation.project?.title.toLowerCase().contains(query) ??
              false) ||
          lastText.contains(query);
    }).toList();
  }
}

class _ConversationListItem extends ConsumerWidget {
  const _ConversationListItem({required this.conversation});

  final _ConversationPreview conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastMessage = ref
        .watch(clientLastMessageProvider(conversation.client.shareToken))
        .asData
        ?.value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/clients/${conversation.client.id}/chat'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              _ConversationAvatar(name: conversation.client.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.client.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.mainTextColor(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _formatConversationDate(lastMessage?.createdAt),
                          style: TextStyle(
                            color: AppTheme.secondaryTextColor(context),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (conversation.project != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        conversation.project!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppTheme.primary(context).withValues(alpha: 0.12),
        shape: BoxShape.circle,
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
    );
  }
}

class _ConversationPreview {
  const _ConversationPreview({
    required this.client,
    required this.project,
    required this.lastMessage,
  });

  final ClientModel client;
  final ProjectModel? project;
  final ClientMessageModel? lastMessage;
}

ProjectModel? _projectForClient(
  ClientModel client,
  List<ProjectModel> projects,
) {
  final matches = projects
      .where((project) => project.clientName == client.name)
      .toList();
  if (matches.isEmpty) return null;
  matches.sort((a, b) {
    final aDone = _isCompleted(a);
    final bDone = _isCompleted(b);
    if (aDone != bDone) return aDone ? 1 : -1;
    return b.progress.compareTo(a.progress);
  });
  return matches.first;
}

bool _isCompleted(ProjectModel project) {
  final status = project.status.trim().toLowerCase();
  return status == 'terminé' || status == 'termine' || project.progress >= 1;
}

String _formatConversationDate(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;

  if (diff == 0) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  if (diff == 1) return 'Hier';

  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  if (date.year == now.year) {
    return '${date.day} ${months[date.month - 1]}';
  }

  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
