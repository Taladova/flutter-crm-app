import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// Icon-only brand mark, rendered from the real Deskly logo artwork.
/// Uses the dark-background icon on a light theme and the light-background
/// icon on a dark theme, so the mark always contrasts with the page.
class DesklyLogo extends StatelessWidget {
  const DesklyLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = AppTheme.isDark(context)
        ? 'assets/images/icon_light_bg.png'
        : 'assets/images/icon_dark_bg.png';

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(asset, width: size, height: size, fit: BoxFit.cover),
    );
  }
}
