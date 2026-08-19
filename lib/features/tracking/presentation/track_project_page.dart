import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
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
      final data = await ref.read(sharedProjectServiceProvider).fetch(code);

      if (!mounted) return;

      setState(() {
        if (data == null) {
          error = 'Aucun projet trouvé avec ce code. Vérifiez auprès de votre contact.';
          result = null;
        } else {
          result = data;
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
      error = null;
      codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: AppTheme.mainTextColor(context)),
                ),
              ),
              const SizedBox(height: 24),
              Text('Suivre un projet', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Entrez le code fourni par votre prestataire pour suivre '
                'l\'avancement de votre projet, sans créer de compte.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, fontSize: 14),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: AppTheme.borderColor(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: AppTheme.borderColor(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _lookup(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5, fontWeight: FontWeight.w600)),
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
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Suivre le projet'),
                  ),
                ),
              ] else
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${data['status']}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${data['title']}',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '${data['clientName']} · ${data['type']}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600),
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
                  Text('$percent%', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
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
              _InfoRow(label: 'Budget', value: '${data['budget']}'),
              const SizedBox(height: 12),
              _InfoRow(label: 'Deadline', value: '${data['deadline']}'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Tâches', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        if (tasks.isEmpty)
          Text('Aucune tâche partagée pour ce projet.', style: TextStyle(color: AppTheme.secondaryTextColor(context), fontSize: 13))
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
                    task['status'] == 'Terminé' ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: task['status'] == 'Terminé' ? const Color(0xFF16A34A) : AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${task['title']}',
                      style: TextStyle(color: AppTheme.mainTextColor(context), fontWeight: FontWeight.w700, fontSize: 13.5),
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
          style: TextStyle(color: AppTheme.secondaryTextColor(context), fontSize: 13, fontWeight: FontWeight.w700),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: AppTheme.mainTextColor(context), fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
