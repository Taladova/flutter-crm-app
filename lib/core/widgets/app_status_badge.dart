import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = _getColors(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: colors.text,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  _BadgeColors _getColors(String status) {
    switch (status) {
      case 'Actif':
      case 'En cours':
      case 'Terminé':
        return const _BadgeColors(
          background: Color(0xFFDCFCE7),
          text: Color(0xFF16A34A),
        );

      case 'En attente':
      case 'Planifié':
        return const _BadgeColors(
          background: Color(0xFFFEF3C7),
          text: Color(0xFFD97706),
        );

      case 'Maquette':
        return const _BadgeColors(
          background: Color(0xFFF3E8FF),
          text: Color(0xFF9333EA),
        );

      case 'Validation':
      case 'Prospect':
        return const _BadgeColors(
          background: Color(0xFFEFF6FF),
          text: AppTheme.primaryColor,
        );

      default:
        return const _BadgeColors(
          background: Color(0xFFF1F5F9),
          text: AppTheme.greyTextColor,
        );
    }
  }
}

class _BadgeColors {
  const _BadgeColors({required this.background, required this.text});

  final Color background;
  final Color text;
}
