import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/deskly_logo.dart';

class RoleChoicePage extends StatelessWidget {
  const RoleChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DesklyLogo(size: 52),
                    const SizedBox(height: 22),
                    Text(
                      'Choisissez votre espace',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontSize: 30, height: 1.05),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Un accès séparé pour gérer votre activité ou suivre un projet client.',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _RoleCard(
                      icon: Icons.business_center_rounded,
                      title: 'Espace pro',
                      eyebrow: 'Professionnel',
                      subtitle:
                          'Gérer clients, projets, tâches, messages et documents.',
                      buttonLabel: 'Continuer',
                      onTap: () => context.go('/login'),
                      filled: true,
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      icon: Icons.person_pin_circle_rounded,
                      title: 'Espace client',
                      eyebrow: 'Client invité',
                      subtitle:
                          'Se connecter, créer son espace ou utiliser un code de suivi.',
                      buttonLabel: 'Continuer',
                      onTap: () => context.go('/client/login'),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'Deskly vous dirige vers le bon espace.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor(context),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.eyebrow,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String title;
  final String eyebrow;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: filled ? AppTheme.primaryColor : AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: filled ? AppTheme.primaryColor : AppTheme.borderColor(context),
        ),
        boxShadow: [
          if (!AppTheme.isDark(context))
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: filled
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: filled ? Colors.white : AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: filled
                            ? Colors.white.withValues(alpha: 0.72)
                            : AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: filled
                            ? Colors.white
                            : AppTheme.mainTextColor(context),
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              color: filled
                  ? Colors.white.withValues(alpha: 0.82)
                  : AppTheme.secondaryTextColor(context),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: filled
                ? FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _ButtonLabel(label: buttonLabel),
                  )
                : OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _ButtonLabel(label: buttonLabel),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    );
  }
}
