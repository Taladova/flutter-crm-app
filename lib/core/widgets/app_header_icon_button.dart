import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// Small square icon button used in page headers (hamburger, notifications,
/// back, etc.) — kept as one shared widget so every page's header looks
/// identical.
class AppHeaderIconButton extends StatelessWidget {
  const AppHeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppTheme.cardColor(context),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Icon(icon, color: AppTheme.mainTextColor(context), size: 22),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
