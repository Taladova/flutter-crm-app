import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// Icon-only brand mark: a lowercase "d" that doubles as a desk seen from
/// above (the stem is a table leg, the bowl is a flattened tabletop).
class DesklyLogo extends StatelessWidget {
  const DesklyLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.23),
      ),
      child: Stack(
        children: [
          Positioned(
            left: size * 0.23,
            top: size * 0.47,
            child: Container(
              width: size * 0.47,
              height: size * 0.29,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.08),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: size * 0.03),
                  child: Container(
                    width: size * 0.35,
                    height: size * 0.02,
                    decoration: BoxDecoration(
                      color: AppTheme.midnight.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(size * 0.01),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: size * 0.59,
            top: size * 0.24,
            child: Container(
              width: size * 0.11,
              height: size * 0.52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.055),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full lockup: icon mark + "Deskly" wordmark, with an optional tagline —
/// used on the splash and login screens.
class DesklyWordmark extends StatelessWidget {
  const DesklyWordmark({super.key, this.markSize = 64, this.showTagline = true, this.onDark = false});

  final double markSize;
  final bool showTagline;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? Colors.white : AppTheme.mainTextColor(context);
    final taglineColor = onDark ? Colors.white.withValues(alpha: 0.7) : AppTheme.secondaryTextColor(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DesklyLogo(size: markSize),
            SizedBox(width: markSize * 0.22),
            Text(
              'deskly',
              style: TextStyle(
                fontSize: markSize * 0.62,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: textColor,
              ),
            ),
          ],
        ),
        if (showTagline) ...[
          SizedBox(height: markSize * 0.22),
          Text(
            'Clients, projets, tâches.',
            style: TextStyle(
              fontSize: markSize * 0.16,
              color: taglineColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
