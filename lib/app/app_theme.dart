import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1C9E85);

  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color darkBackgroundColor = Color(0xFF000B27);

  static const Color darkTextColor = Color(0xFF0F172A);
  static const Color lightTextColor = Color(0xFFFFFFFF);
  static const Color greyTextColor = Color(0xFF64748B);

  static const Color lightCardColor = Colors.white;
  static const Color darkCardColor = Color(0xFF071633);

  static const Color lightBorderColor = Color(0xFFE2E8F0);
  static const Color darkBorderColor = Color(0xFF1C2D4A);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      fontFamily: 'Inter',
      cardColor: lightCardColor,
      dividerColor: lightBorderColor,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: darkTextColor,
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
        headlineMedium: TextStyle(
          color: darkTextColor,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
        titleLarge: TextStyle(
          color: darkTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        bodyMedium: TextStyle(
          color: greyTextColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackgroundColor,
      primaryColor: primaryColor,
      fontFamily: 'Inter',
      cardColor: darkCardColor,
      dividerColor: darkBorderColor,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: lightTextColor,
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
        headlineMedium: TextStyle(
          color: lightTextColor,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
        titleLarge: TextStyle(
          color: lightTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color pageBackground(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color cardColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  static Color borderColor(BuildContext context) {
    return Theme.of(context).dividerColor;
  }

  static Color mainTextColor(BuildContext context) {
    return isDark(context) ? lightTextColor : darkTextColor;
  }

  static Color secondaryTextColor(BuildContext context) {
    return isDark(context) ? const Color(0xFFA7B3C8) : greyTextColor;
  }
}
