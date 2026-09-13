import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/currency_text.dart';
import '../../../data/models/client_message_model.dart';
import '../../../data/providers/firestore_providers.dart';

class TrackProjectPage extends ConsumerStatefulWidget {
  const TrackProjectPage({super.key});

  @override
  ConsumerState<TrackProjectPage> createState() => _TrackProjectPageState();
}

class _TrackProjectPageState extends ConsumerState<TrackProjectPage> {
  final codeController = TextEditingController();
  bool isLoading = false;
  String? error;
  Map<String, dynamic>? result;
  String? resultType;
  String? activeToken;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = codeController.text.trim();

    if (code.isEmpty) {
      setState(() => error = 'Merci de saisir un code.');
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final projectData = await ref
          .read(sharedProjectServiceProvider)
          .fetch(code);

      if (!mounted) return;

      if (projectData != null) {
        setState(() {
          result = projectData;
          resultType = 'project';
          activeToken = code.trim().toUpperCase();
        });
        return;
      }

      final clientData = await ref
          .read(sharedClientServiceProvider)
          .fetch(code);

      if (!mounted) return;

      setState(() {
        if (clientData == null) {
          error =
              'Aucun résultat pour ce code. Vérifiez auprès de votre contact.';
          result = null;
          resultType = null;
        } else {
          result = clientData;
          resultType = 'client';
          activeToken = code.trim().toUpperCase();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'Impossible de vérifier ce code pour le moment.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _reset() {
    setState(() {
      result = null;
      resultType = null;
      activeToken = null;
      error = null;
      codeController.clear();
    });
  }

  void _goBackToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/role-choice');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showChat =
        result != null && resultType == 'client' && activeToken != null;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: showChat
            ? _ClientChatResult(
                token: activeToken!,
                clientName: '${result!['clientName']}',
                onBack: _reset,
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _goBackToLogin,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor(context),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: AppTheme.borderColor(context),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: AppTheme.mainTextColor(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Suivre un projet',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entrez le code fourni par votre prestataire pour suivre '
                      'l\'avancement de votre projet ou échanger des messages, sans créer de compte.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (result == null) ...[
                      TextField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                          color: AppTheme.mainTextColor(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 3,
                        ),
                        decoration: InputDecoration(
                          hintText: 'CODE',
                          filled: true,
                          fillColor: AppTheme.cardColor(context),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
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
                        onSubmitted: (_) => _lookup(),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _lookup,
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Suivre le projet'),
                        ),
                      ),
                    ] else if (resultType == 'project')
                      _TrackResult(data: result!, onBack: _reset),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TrackResult extends StatelessWidget {
  const _TrackResult({required this.data, required this.onBack});

  final Map<String, dynamic> data;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
    final percent = (progress * 100).round();
    final tasks = (data['tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${data['status']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${data['title']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${data['clientName']} · ${data['type']}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
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
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: 'Budget',
                value: formatCurrencyText('${data['budget']}'),
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Échéance', value: '${data['deadline']}'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Tâches', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${tasks.length}',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (tasks.isEmpty)
          Text(
            'Aucune tâche partagée pour ce projet.',
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 13,
            ),
          )
        else
          ...tasks.map(
            (task) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    task['status'] == 'Terminé'
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: task['status'] == 'Terminé'
                        ? const Color(0xFF16A34A)
                        : AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${task['title']}',
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: onBack,
            child: const Text('Suivre un autre projet'),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label : ',
          style: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClientChatResult extends ConsumerStatefulWidget {
  const _ClientChatResult({
    required this.token,
    required this.clientName,
    required this.onBack,
  });

  final String token;
  final String clientName;
  final VoidCallback onBack;

  @override
  ConsumerState<_ClientChatResult> createState() => _ClientChatResultState();
}

class _ClientChatResultState extends ConsumerState<_ClientChatResult> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  bool isSending = false;

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => isSending = true);
    messageController.clear();

    // TEMP DIAGNOSTIC LOG — see clientflow_pro professional/client link audit.
    // This public tracking page is reached by share code, without Firebase
    // Auth, so there is deliberately no currentAuthUid/senderUid here.
    // ignore: avoid_print
    print(
      '[chat][track-public] currentAuthUid=null role=anonymous-client '
      'sharedClientId=${widget.token} senderType=client senderUid=null '
      'path=shared_clients/${widget.token}/messages',
    );

    try {
      await ref
          .read(sharedClientServiceProvider)
          .sendMessage(token: widget.token, senderType: 'client', text: text);

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(15),
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
                      'Messages',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.clientName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<List<ClientMessageModel>>(
            stream: ref
                .read(sharedClientServiceProvider)
                .messagesStream(widget.token),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!;

              if (messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Aucun message pour le moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToEnd(),
              );

              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMine = !message.isFromFreelancer;

                  return Align(
                    alignment: isMine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isMine
                            ? AppTheme.primaryColor
                            : AppTheme.cardColor(context),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMine ? 18 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 18),
                        ),
                        border: isMine
                            ? null
                            : Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: isMine
                              ? Colors.white
                              : AppTheme.mainTextColor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            border: Border(
              top: BorderSide(color: AppTheme.borderColor(context)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Écrire un message...',
                    filled: true,
                    fillColor: AppTheme.pageBackground(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: isSending ? null : _send,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: isSending
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
