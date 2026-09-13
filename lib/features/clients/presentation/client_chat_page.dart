import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../data/models/client_message_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../client_portal/providers/client_portal_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../providers/client_providers.dart';

class ClientChatPage extends ConsumerStatefulWidget {
  const ClientChatPage({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientChatPage> createState() => _ClientChatPageState();
}

class _ClientChatPageState extends ConsumerState<ClientChatPage> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  bool isPreparingAccess = false;
  bool isSending = false;
  int lastRenderedMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureShareToken());
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureShareToken() async {
    final client = ref.read(clientByIdProvider(widget.clientId));
    if (client == null) return;

    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    // publish() short-circuits to the cached client.shareToken when it's
    // already set, so calling it again here is cheap — but we still need
    // to run every time so an already-linked client account gets its
    // client_accounts.sharedClientId (re)synced to this same token.
    if (!client.isShared) setState(() => isPreparingAccess = true);

    // TEMP DIAGNOSTIC LOG — see clientflow_pro "espace client" audit.
    // ignore: avoid_print
    print(
      '[client-space] START\n'
      '[client-space] currentAuthUid=$uid\n'
      '[client-space] clientId=${client.id}\n'
      '[client-space] professionalId=$uid\n'
      '[client-space] sharedClientId=${client.shareToken}\n'
      '[client-space] firestorePath=shared_clients/${client.shareToken.isEmpty ? '(to resolve)' : client.shareToken}',
    );

    try {
      final token = await ref
          .read(sharedClientServiceProvider)
          .publish(ownerUid: uid, client: client);

      // Source of truth reconciliation: whatever token the professional's
      // side resolves to is written onto the linked client_accounts record,
      // so the client side reads it straight from
      // client_accounts/{clientUid}.sharedClientId instead of ever
      // re-deriving — or diverging on — its own id.
      await ref
          .read(clientPortalServiceProvider)
          .syncSharedClientIdToAccounts(
            professionalId: uid,
            token: token,
            clientId: client.id,
            clientName: client.name,
            clientEmail: client.email,
          );

      if (!client.isShared) {
        await ref
            .read(clientControllerProvider.notifier)
            .updateClient(client.copyWith(shareToken: token));
      }

      // ignore: avoid_print
      print('[client-space] DONE sharedClientId=$token');
    } on FirebaseException catch (e, stackTrace) {
      // ignore: avoid_print
      print(
        '[client-space] FAILED\n'
        '  code=${e.code}\n'
        '  message=${e.message}\n'
        '  stackTrace=$stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de préparer l\'espace client.'),
        ),
      );
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print(
        '[client-space] FAILED (non-Firebase) error=$e\n'
        '  stackTrace=$stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de préparer l\'espace client.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isPreparingAccess = false);
    }
  }

  Future<void> _send(String token) async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    final client = ref.read(clientByIdProvider(widget.clientId));
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (client == null || uid == null) return;

    setState(() => isSending = true);
    messageController.clear();

    // TEMP DIAGNOSTIC LOG — see clientflow_pro professional/client link audit.
    // ignore: avoid_print
    print(
      '[chat][pro] currentAuthUid=$uid role=professional '
      'professionalId=$uid clientId=${client.id} sharedClientId=$token '
      'senderType=freelancer senderUid=$uid '
      'path=shared_clients/$token/messages',
    );

    try {
      await ref
          .read(sharedClientServiceProvider)
          .sendMessage(
            token: token,
            senderType: 'freelancer',
            text: text,
            senderUid: uid,
          );

      await ref
          .read(clientPortalServiceProvider)
          .notifyClientAccountsOfProfessionalMessage(
            professionalId: uid,
            clientId: client.id,
            clientName: client.name,
            clientEmail: client.email,
          );

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
      }
    } catch (_) {
      if (!mounted) return;
      messageController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message non envoyé, réessayez.')),
      );
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _scrollToEnd() {
    if (!scrollController.hasClients) return;
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  bool _isNearBottom() {
    if (!scrollController.hasClients) return true;
    final position = scrollController.position;
    return position.maxScrollExtent - position.pixels < 180;
  }

  Future<void> _shareCode(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copié — envoyez-le à votre client.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(clientByIdProvider(widget.clientId));
    final projects = ref.watch(projectControllerProvider).value ?? [];

    if (client == null) {
      return const Scaffold(body: Center(child: Text('Client introuvable')));
    }

    final relatedProject = _projectForClient(client.name, projects);
    final messagesAsync = client.isShared
        ? ref.watch(clientMessagesProvider(client.shareToken))
        : const AsyncValue<List<ClientMessageModel>>.data([]);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              clientName: client.name,
              projectName: relatedProject?.title,
              hasCode: client.isShared,
              onBack: () => context.pop(),
              onOpenClient: () => context.push('/clients/${client.id}'),
              onOpenProject: relatedProject == null
                  ? null
                  : () => context.push('/projects/${relatedProject.id}'),
              onShowAccess: client.isShared
                  ? () => _showAccessInfo(client.shareToken)
                  : null,
              onCopyCode: client.isShared
                  ? () => _shareCode(client.shareToken)
                  : null,
            ),
            Expanded(
              child: isPreparingAccess
                  ? const _ChatLoading()
                  : !client.isShared
                  ? const _ChatLoading()
                  : messagesAsync.when(
                      loading: () => const _ChatLoading(),
                      error: (error, stackTrace) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: AppTheme.secondaryTextColor(context),
                                size: 32,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Impossible de charger les messages.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.mainTextColor(context),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Réessayez dans quelques instants.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.secondaryTextColor(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      data: (messages) {
                        if (messages.isEmpty) {
                          return _EmptyChat(clientName: client.name);
                        }

                        final shouldScroll =
                            lastRenderedMessageCount == 0 || _isNearBottom();
                        lastRenderedMessageCount = messages.length;
                        if (shouldScroll) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _scrollToEnd(),
                          );
                        }

                        final items = _buildChatItems(messages);
                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (item.dateLabel != null) {
                              return _DateSeparator(label: item.dateLabel!);
                            }
                            return _MessageBubble(item: item);
                          },
                        );
                      },
                    ),
            ),
            _Composer(
              controller: messageController,
              isSending: isSending,
              enabled: client.isShared && !isPreparingAccess,
              onSend: client.isShared ? () => _send(client.shareToken) : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAccessInfo(String token) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardColor(context),
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
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Espace client',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'Code d’accès',
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(sheetContext),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondarySurface(sheetContext),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.borderColor(sheetContext),
                    ),
                  ),
                  child: Text(
                    token,
                    style: TextStyle(
                      color: AppTheme.primary(sheetContext),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _shareCode(token);
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copier le code'),
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

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.clientName,
    required this.projectName,
    required this.hasCode,
    required this.onBack,
    required this.onOpenClient,
    required this.onOpenProject,
    required this.onShowAccess,
    required this.onCopyCode,
  });

  final String clientName;
  final String? projectName;
  final bool hasCode;
  final VoidCallback onBack;
  final VoidCallback onOpenClient;
  final VoidCallback? onOpenProject;
  final VoidCallback? onShowAccess;
  final VoidCallback? onCopyCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppTheme.pageBackground(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor(context)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.mainTextColor(context),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (projectName != null && projectName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    projectName!,
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
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: AppTheme.mainTextColor(context),
            ),
            color: AppTheme.cardColor(context),
            onSelected: (value) {
              switch (value) {
                case 'project':
                  onOpenProject?.call();
                  break;
                case 'client':
                  onOpenClient();
                  break;
                case 'access':
                  onShowAccess?.call();
                  break;
                case 'copy':
                  onCopyCode?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (onOpenProject != null)
                const PopupMenuItem(
                  value: 'project',
                  child: _MenuItem(
                    icon: Icons.work_outline_rounded,
                    label: 'Voir le projet',
                  ),
                ),
              const PopupMenuItem(
                value: 'client',
                child: _MenuItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Voir le client',
                ),
              ),
              if (hasCode)
                const PopupMenuItem(
                  value: 'access',
                  child: _MenuItem(
                    icon: Icons.info_outline_rounded,
                    label: 'Informations de l’espace client',
                  ),
                ),
              if (hasCode)
                const PopupMenuItem(
                  value: 'copy',
                  child: _MenuItem(
                    icon: Icons.copy_rounded,
                    label: 'Copier le code',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.secondaryTextColor(context)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatLoading extends StatelessWidget {
  const _ChatLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppTheme.primary(context),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.clientName});

  final String clientName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 44,
              color: AppTheme.secondaryTextColor(
                context,
              ).withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            Text(
              'Aucun message',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.mainTextColor(context),
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Démarrez la conversation avec $clientName.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.item});

  final _ChatListItem item;

  @override
  Widget build(BuildContext context) {
    final message = item.message!;
    final isMine = message.isFromFreelancer;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          top: item.showAuthor
              ? 10
              : item.isSameAuthorAsPrevious
              ? 3
              : 8,
          bottom: 2,
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (item.showAuthor && !isMine) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  item.authorLabel,
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: isMine
                    ? AppTheme.primary(context)
                    : AppTheme.secondarySurface(context),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(
                    !isMine && item.isSameAuthorAsPrevious ? 8 : 17,
                  ),
                  topRight: Radius.circular(
                    isMine && item.isSameAuthorAsPrevious ? 8 : 17,
                  ),
                  bottomLeft: Radius.circular(isMine ? 17 : 6),
                  bottomRight: Radius.circular(isMine ? 6 : 17),
                ),
                border: isMine
                    ? null
                    : Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMine
                          ? Colors.white
                          : AppTheme.mainTextColor(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.32,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: TextStyle(
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.72)
                          : AppTheme.secondaryTextColor(context),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppTheme.borderColor(context))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppTheme.borderColor(context))),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool enabled;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.secondarySurface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Écrire un message...',
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: enabled && !isSending ? onSend : null,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: enabled
                    ? AppTheme.primary(context)
                    : AppTheme.borderColor(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatListItem {
  const _ChatListItem.message({
    required this.message,
    required this.showAuthor,
    required this.isSameAuthorAsPrevious,
  }) : dateLabel = null;

  const _ChatListItem.date(this.dateLabel)
    : message = null,
      showAuthor = false,
      isSameAuthorAsPrevious = false;

  final ClientMessageModel? message;
  final String? dateLabel;
  final bool showAuthor;
  final bool isSameAuthorAsPrevious;

  String get authorLabel {
    final senderType = message?.senderType;
    return senderType == 'freelancer' ? 'Vous' : 'Client';
  }
}

List<_ChatListItem> _buildChatItems(List<ClientMessageModel> messages) {
  final items = <_ChatListItem>[];
  String? previousDayKey;
  String? previousSender;

  for (final message in messages) {
    final dayKey = _dayKey(message.createdAt);
    if (dayKey != previousDayKey) {
      items.add(_ChatListItem.date(_formatMessageDate(message.createdAt)));
      previousDayKey = dayKey;
      previousSender = null;
    }

    final sameAuthor = previousSender == message.senderType;
    items.add(
      _ChatListItem.message(
        message: message,
        showAuthor: !sameAuthor,
        isSameAuthorAsPrevious: sameAuthor,
      ),
    );
    previousSender = message.senderType;
  }

  return items;
}

ProjectModel? _projectForClient(
  String clientName,
  List<ProjectModel> projects,
) {
  final normalizedClient = clientName.trim().toLowerCase();
  if (normalizedClient.isEmpty) return null;

  final matches = projects
      .where(
        (project) =>
            project.clientName.trim().toLowerCase() == normalizedClient,
      )
      .toList();
  if (matches.isEmpty) return null;

  matches.sort((a, b) {
    final aCompleted = _isCompletedProject(a);
    final bCompleted = _isCompletedProject(b);
    if (aCompleted != bCompleted) return aCompleted ? 1 : -1;
    return a.title.compareTo(b.title);
  });

  return matches.first;
}

bool _isCompletedProject(ProjectModel project) {
  final status = project.status.trim().toLowerCase();
  return status == 'terminé' || status == 'termine';
}

String _formatMessageTime(DateTime? date) {
  if (date == null) return '--:--';
  return '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
}

String _formatMessageDate(DateTime? date) {
  if (date == null) return 'Aujourd’hui';
  final day = _dateOnly(date);
  final today = _dateOnly(DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));

  if (day == today) return 'Aujourd’hui';
  if (day == yesterday) return 'Hier';
  return '${day.day} ${_monthName(day.month)} ${day.year}';
}

String _dayKey(DateTime? date) {
  final value = date ?? DateTime.now();
  return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

String _monthName(int month) {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return months[month - 1];
}
