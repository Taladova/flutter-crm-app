import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Which side of Deskly is rendering: the professional's own workspace, or
/// the client portal. Same brand, two visual identities — see
/// [ProThemeTokens] / [ClientThemeTokens] and [AppRoleTheme].
enum AppRole { professional, client }

/// Professional workspace tokens: more contrast, denser, built for
/// steering work (clients, projects, actions).
class ProThemeTokens {
  const ProThemeTokens._();

  static const Color primary = Color(0xFF31BB80);
  static const Color deepTeal = Color(0xFF203E40);
  static const Color background = Color(0xFFF5F7F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color softPrimary = Color(0xFFDDF5EA);
  static const Color border = Color(0xFFD9E5E1);
  static const Color primaryText = Color(0xFF172625);
  static const Color secondaryText = Color(0xFF687A77);
}

/// Client portal tokens: softer, more premium, more air — built for
/// following progress and building trust rather than dense daily steering.
class ClientThemeTokens {
  const ClientThemeTokens._();

  static const Color primary = Color(0xFF31BB80);
  static const Color clientDeep = Color(0xFF2B5954);
  static const Color clientSage = Color(0xFF6FAE96);
  static const Color clientSecondary = Color(0xFF5F8F8B);
  static const Color background = Color(0xFFF4F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color softSurface = Color(0xFFE7F5EF);
  static const Color border = Color(0xFFD5E5DF);
  static const Color primaryText = Color(0xFF203E40);
  static const Color secondaryText = Color(0xFF70827D);
}

/// Builds the two role-scoped [ThemeData]s from [ProThemeTokens] /
/// [ClientThemeTokens], through the exact same recipe as AppTheme's
/// existing light/dark theme ([AppTheme.buildThemeData]) — one shared
/// Material theming pipeline, never a second one, and no color hardcoded
/// in a widget.
///
/// Applied per-route in app_router.dart (see `_proThemed`/`_clientThemed`),
/// wrapping each role's pages in a `Theme` — ClientFlowApp's own
/// `theme`/`darkTheme` (AppTheme.lightTheme/darkTheme) is unaffected.
/// Every existing AppTheme.xxx(context) helper keeps working unchanged
/// since it reads from Theme.of(context), so no page needed editing to
/// pick up its role's palette.
class AppRoleTheme {
  const AppRoleTheme._({required this.role, required this.themeData});

  final AppRole role;
  final ThemeData themeData;

  static final AppRoleTheme professional = AppRoleTheme._(
    role: AppRole.professional,
    themeData: AppTheme.buildThemeData(
      brightness: Brightness.light,
      primary: ProThemeTokens.primary,
      secondary: ProThemeTokens.deepTeal,
      background: ProThemeTokens.background,
      surface: ProThemeTokens.surface,
      secondarySurface: ProThemeTokens.softPrimary,
      softPrimary: ProThemeTokens.softPrimary,
      border: ProThemeTokens.border,
      mainText: ProThemeTokens.primaryText,
      secondaryText: ProThemeTokens.secondaryText,
      // Pro is the denser, more contrasted, action-oriented side — see
      // AppTheme.buildThemeData's boldEmphasis doc.
      boldEmphasis: true,
    ),
  );

  static final AppRoleTheme client = AppRoleTheme._(
    role: AppRole.client,
    themeData: AppTheme.buildThemeData(
      brightness: Brightness.light,
      primary: ClientThemeTokens.primary,
      secondary: ClientThemeTokens.clientDeep,
      background: ClientThemeTokens.background,
      surface: ClientThemeTokens.surface,
      secondarySurface: ClientThemeTokens.softSurface,
      softPrimary: ClientThemeTokens.softSurface,
      border: ClientThemeTokens.border,
      mainText: ClientThemeTokens.primaryText,
      secondaryText: ClientThemeTokens.secondaryText,
      // #31BB80 stays reserved for primary CTAs; ClientSage carries the
      // portal's everyday accent instead (AppTheme.accent(context)).
      tertiary: ClientThemeTokens.clientSage,
      onTertiary: ClientThemeTokens.primaryText,
    ),
  );

  static AppRoleTheme of(AppRole role) {
    return switch (role) {
      AppRole.professional => professional,
      AppRole.client => client,
    };
  }
}
