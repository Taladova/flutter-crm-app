import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Confidentialité & mentions légales',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _Section(
                title: 'Données collectées',
                body:
                    'Deskly collecte votre nom et votre adresse e-mail lors de la création de '
                    'votre compte, ainsi que les données que vous saisissez vous-même dans '
                    'l\'application : clients, projets, tâches et notes associées. Ces '
                    'données ne sont ni revendues ni utilisées à des fins publicitaires.',
              ),
              const _Section(
                title: 'Stockage & sécurité',
                body:
                    'Vos données sont stockées via Firebase Authentication et Cloud '
                    'Firestore (Google), chiffrées en transit et au repos. Chaque compte '
                    'accède uniquement à ses propres données : nos règles de sécurité '
                    'empêchent tout autre utilisateur d\'y accéder.',
              ),
              const _Section(
                title: 'Suivi & analyse',
                body:
                    'Deskly n\'intègre aucun outil de suivi publicitaire ni d\'analyse '
                    'comportementale tierce à ce jour.',
              ),
              const _Section(
                title: 'Vos droits',
                body:
                    'Vous pouvez accéder à vos données, les corriger ou demander leur '
                    'suppression à tout moment en nous contactant à l\'adresse ci-dessous. '
                    'Vous pouvez aussi vous déconnecter à tout moment depuis Paramètres > Compte.',
              ),
              const _Section(
                title: 'Éditeur',
                body:
                    'Cette section doit être complétée avec la raison sociale, l\'adresse et '
                    'le numéro SIRET de l\'éditeur avant toute publication publique sur les '
                    'stores, conformément à la réglementation en vigueur.',
                isPlaceholder: true,
              ),
              const _Section(
                title: 'Contact',
                body:
                    'contact@deskly.app (à remplacer par votre adresse réelle)',
                isPlaceholder: true,
              ),
              const SizedBox(height: 8),
              Text(
                'Dernière mise à jour : ce document est un modèle de bonne foi et ne '
                'constitue pas un avis juridique. Faites-le relire avant publication.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.secondaryTextColor(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.body,
    this.isPlaceholder = false,
  });

  final String title;
  final String body;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPlaceholder
                ? const Color(0xFFD97706).withValues(alpha: 0.4)
                : AppTheme.borderColor(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (isPlaceholder) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'À compléter',
                      style: TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontSize: 13.5,
                height: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
