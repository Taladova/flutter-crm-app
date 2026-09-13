import 'package:flutter/material.dart';

class AppTheme {
  static const Color mint = Color(0xFF31BB80);
  static const Color mintDark = Color(0xFF249967);
  static const Color deepTeal = Color(0xFF203E40);
  static const Color deepTealSecondary = Color(0xFF284F50);
  static const Color darkMint = Color(0xFF38C98B);

  static const Color desklyGreen = mint;
  static const Color desklyBlue = deepTealSecondary;
  static const Color desklyGold = Color(0xFFD7B06A);

  static const Color lightBackgroundColor = Color(0xFFF6F8F7);
  static const Color lightSurfaceColor = Color(0xFFFFFFFF);
  static const Color lightSecondarySurfaceColor = Color(0xFFEEF5F2);
  static const Color lightSoftPrimaryColor = Color(0xFFDDF5EA);
  static const Color lightBorderColor = Color(0xFFDDE7E3);
  static const Color lightPrimaryTextColor = Color(0xFF162625);
  static const Color lightSecondaryTextColor = Color(0xFF687A77);

  static const Color darkBackgroundColor = Color(0xFF142728);
  static const Color darkSecondaryBackgroundColor = Color(0xFF254344);
  static const Color darkSurfaceColor = Color(0xFF1C3435);
  static const Color darkBorderColor = Color(0xFF345758);
  static const Color darkPrimaryTextColor = Color(0xFFF4F8F7);
  static const Color darkSecondaryTextColor = Color(0xFFB7C8C5);
  static const Color darkPrimaryColor = darkMint;
  static const Color darkSecondaryColor = deepTealSecondary;
  static const Color darkAccentColor = desklyGold;

  static const Color errorColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFD97706);
  static const Color successColor = Color(0xFF16A34A);

  static const Color primaryColor = desklyGreen;
  static const Color secondaryColor = desklyBlue;
  static const Color accentColor = desklyGold;

  // Backward-compatible aliases while pages migrate to semantic helpers.
  static const Color green = desklyGreen;
  static const Color greenDeep = mintDark;
  static const Color midnight = lightPrimaryTextColor;
  static const Color backgroundColor = lightBackgroundColor;
  static const Color darkTextColor = lightPrimaryTextColor;
  static const Color lightTextColor = darkPrimaryTextColor;
  static const Color greyTextColor = lightSecondaryTextColor;
  static const Color lightCardColor = lightSurfaceColor;
  static const Color darkCardColor = darkSurfaceColor;

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [mint, mintDark],
  );

  static Color _primaryFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkPrimaryColor : desklyGreen;
  }

  static Color _secondaryFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkSecondaryColor : deepTeal;
  }

  static Color _backgroundFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkBackgroundColor
        : lightBackgroundColor;
  }

  static Color _surfaceFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkSurfaceColor : lightSurfaceColor;
  }

  static Color _secondarySurfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkSecondaryBackgroundColor
        : lightSecondarySurfaceColor;
  }

  static Color _borderFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkBorderColor : lightBorderColor;
  }

  static Color _mainTextFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkPrimaryTextColor
        : lightPrimaryTextColor;
  }

  static Color _secondaryTextFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkSecondaryTextColor
        : lightSecondaryTextColor;
  }

  static ThemeData _theme(Brightness brightness) {
    final isDarkMode = brightness == Brightness.dark;
    return buildThemeData(
      brightness: brightness,
      primary: _primaryFor(brightness),
      secondary: _secondaryFor(brightness),
      background: _backgroundFor(brightness),
      surface: _surfaceFor(brightness),
      secondarySurface: _secondarySurfaceFor(brightness),
      softPrimary: isDarkMode ? deepTealSecondary : lightSoftPrimaryColor,
      border: _borderFor(brightness),
      mainText: _mainTextFor(brightness),
      secondaryText: _secondaryTextFor(brightness),
    );
  }

  /// Shared Material theme recipe: given a role/mode's raw color tokens,
  /// produces the full ThemeData (ColorScheme + every component theme).
  /// AppTheme's own light/dark themes and [AppRoleTheme]'s Pro/Client
  /// themes both go through this one builder — no second theme-building
  /// pipeline, no colors hardcoded per widget.
  static ThemeData buildThemeData({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color secondarySurface,
    required Color softPrimary,
    required Color border,
    required Color mainText,
    required Color secondaryText,
    // Denser, more assertive component styling — CTAs with real weight,
    // borders/status accents that read clearly — without touching a single
    // page's layout. Off by default (AppTheme's own light/dark theme is
    // unchanged); AppRoleTheme.professional turns it on.
    bool boldEmphasis = false,
    // AppTheme.accent(context) source. Defaults to the brand gold everywhere
    // except where a role overrides it (AppRoleTheme.client uses
    // ClientThemeTokens.clientSage here, so widgets already reading
    // AppTheme.accent(context) lean on it without any per-widget change).
    Color tertiary = desklyGold,
    Color onTertiary = lightPrimaryTextColor,
  }) {
    final isDarkMode = brightness == Brightness.dark;

    final colorScheme =
        ColorScheme(
          brightness: brightness,
          primary: primary,
          onPrimary: Colors.white,
          secondary: secondary,
          onSecondary: Colors.white,
          error: errorColor,
          onError: Colors.white,
          surface: surface,
          onSurface: mainText,
        ).copyWith(
          primaryContainer: softPrimary,
          onPrimaryContainer: isDarkMode ? darkPrimaryTextColor : secondary,
          secondaryContainer: secondarySurface,
          onSecondaryContainer: mainText,
          surfaceContainerHighest: secondarySurface,
          outline: border,
          outlineVariant: border.withValues(
            alpha: isDarkMode ? 0.72 : (boldEmphasis ? 0.92 : 0.78),
          ),
          tertiary: tertiary,
          onTertiary: onTertiary,
        );

    final textTheme = TextTheme(
      headlineLarge: TextStyle(
        color: mainText,
        fontSize: 34,
        fontWeight: FontWeight.w900,
      ),
      headlineMedium: TextStyle(
        color: mainText,
        fontSize: 26,
        fontWeight: FontWeight.w900,
      ),
      titleLarge: TextStyle(
        color: mainText,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
      titleMedium: TextStyle(
        color: mainText,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
      bodyLarge: TextStyle(
        color: mainText,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(
        color: secondaryText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: TextStyle(
        color: secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      cardColor: surface,
      dividerColor: border,
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDarkMode ? secondarySurface : surface,
        hintStyle: TextStyle(color: secondaryText),
        labelStyle: TextStyle(color: secondaryText),
        prefixIconColor: secondaryText,
        suffixIconColor: secondaryText,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: errorColor, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: secondarySurface,
          disabledForegroundColor: secondaryText,
          elevation: boldEmphasis ? 1.5 : 0,
          shadowColor: boldEmphasis ? primary.withValues(alpha: 0.35) : null,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: secondarySurface,
        selectedColor: primary,
        disabledColor: secondarySurface.withValues(alpha: 0.62),
        labelStyle: TextStyle(
          color: secondaryText,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        side: BorderSide(color: border, width: boldEmphasis ? 1.3 : 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDarkMode ? darkSecondaryBackgroundColor : surface,
        indicatorColor: primary.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : secondaryText.withValues(alpha: 0.78),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? primary
                : secondaryText.withValues(alpha: 0.82),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: primary,
        unselectedLabelColor: secondaryText,
        indicatorColor: primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: mainText, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDarkMode ? darkSurfaceColor : lightPrimaryTextColor,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : secondaryText.withValues(alpha: 0.72),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.28)
              : secondarySurface,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : surface,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: border, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: secondarySurface,
        circularTrackColor: secondarySurface,
      ),
    );
  }

  static ThemeData get lightTheme => _theme(Brightness.light);

  static ThemeData get darkTheme => _theme(Brightness.dark);

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color pageBackground(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color cardColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  static Color secondarySurface(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static Color borderColor(BuildContext context) {
    return Theme.of(context).dividerColor;
  }

  static Color mainTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color secondaryTextColor(BuildContext context) {
    return isDark(context) ? darkSecondaryTextColor : lightSecondaryTextColor;
  }

  static Color primary(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color secondary(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }

  static Color accent(BuildContext context) {
    return Theme.of(context).colorScheme.tertiary;
  }

  static Color softPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.primaryContainer;
  }

  static Color deepTealColor(BuildContext context) {
    return isDark(context) ? darkPrimaryTextColor : deepTeal;
  }

  static Color success(BuildContext context) {
    return isDark(context) ? darkPrimaryColor : successColor;
  }

  static Color warning(BuildContext context) {
    return warningColor;
  }

  static Color error(BuildContext context) {
    return errorColor;
  }
}
