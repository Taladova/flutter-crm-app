import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import 'app_card.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.secondaryTextColor(context).withOpacity(0.8)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
