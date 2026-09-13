import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../data/models/client_message_model.dart';
import '../providers/client_portal_providers.dart';
import 'client_portal_theme.dart';

class ClientMessagesPage extends ConsumerStatefulWidget {
  const ClientMessagesPage({super.key});

  @override
  ConsumerState<ClientMessagesPage> createState() => _ClientMessagesPageState();
}

class _ClientMessagesPageState extends ConsumerState<ClientMessagesPage> {
  final controller = TextEditingController();
  bool isSending = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    controller.clear();
    setState(() => isSending = true);
    try {
      await ref.read(clientPortalServiceProvider).sendClientMessage(text);
    } catch (_) {
      controller.text = text;
      controller.selection = TextSelection.collapsed(offset: text.length);
      rethrow;
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(clientPortalMessagesProvider);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
              child: const _MessagesHeader(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ClientPortalColors.subtleIconSurface(),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: ClientPortalColors.sage,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conversation avec votre prestataire',
                            style: TextStyle(
                              color: AppTheme.mainTextColor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Messages liés à votre projet',
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
              ),
            ),
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Messages indisponibles',
                  description: 'Impossible de charger la conversation.',
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: AppEmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Aucun message',
                        description:
                            'Commencez la conversation avec votre prestataire.',
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isClient = message.senderType == 'client';
                      return _MessageBubble(
                        message: message,
                        isClient: isClient,
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Écrire un message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: isSending ? null : _send,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          fixedSize: const Size(46, 46),
                        ),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Messages', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Échangez simplement avec votre prestataire.',
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isClient});

  final ClientMessageModel message;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isClient ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: isClient
              ? ClientPortalColors.deep
              : AppTheme.cardColor(context),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isClient ? 18 : 5),
            bottomRight: Radius.circular(isClient ? 5 : 18),
          ),
          border: isClient
              ? null
              : Border.all(color: AppTheme.borderColor(context)),
          boxShadow: [
            if (!AppTheme.isDark(context))
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isClient
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isClient
                    ? Colors.white
                    : AppTheme.mainTextColor(context),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (message.createdAt != null) ...[
              const SizedBox(height: 5),
              Text(
                _formatMessageTime(message.createdAt!),
                style: TextStyle(
                  color: isClient
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppTheme.secondaryTextColor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatMessageTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
