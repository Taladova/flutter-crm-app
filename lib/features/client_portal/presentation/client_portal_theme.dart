import 'package:flutter/material.dart';

import '../../../app/app_role_theme.dart';

class ClientPortalColors {
  const ClientPortalColors._();

  static const Color background = ClientThemeTokens.background;
  static const Color primaryText = ClientThemeTokens.primaryText;
  static const Color secondaryText = ClientThemeTokens.secondaryText;
  static const Color deep = ClientThemeTokens.clientDeep;
  static const Color secondary = ClientThemeTokens.clientSecondary;
  static const Color sage = ClientThemeTokens.clientSage;
  static const Color softSurface = ClientThemeTokens.softSurface;
  static const Color border = ClientThemeTokens.border;
  static const Color cta = ClientThemeTokens.primary;

  static Color subtleIconSurface() => sage.withValues(alpha: 0.16);
  static Color calmSurface() => softSurface.withValues(alpha: 0.72);
  static Color deepInnerSurface() => secondary.withValues(alpha: 0.32);
}
