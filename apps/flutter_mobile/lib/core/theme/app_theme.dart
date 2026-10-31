import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const primaryDarkGreen = Color(0xFF003327);
  static const primaryEmerald = Color(0xFF164A3C);
  static const lightMint = Color(0xFFE7F4EF);
  static const secondaryMint = Color(0xFF6FFBBE);
  static const background = Color(0xFFF7FAF9);
  static const primaryText = Color(0xFF15211D);
  static const secondaryText = Color(0xFF718079);
  static const border = Color(0xFFDCE7E2);
  static const error = Color(0xFFD64545);
  static const warning = Color(0xFFD99A32);

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primaryEmerald,
          brightness: Brightness.light,
        ).copyWith(
          primary: primaryEmerald,
          onPrimary: Colors.white,
          primaryContainer: lightMint,
          onPrimaryContainer: primaryDarkGreen,
          secondary: const Color(0xFF006C49),
          secondaryContainer: secondaryMint,
          onSecondaryContainer: primaryDarkGreen,
          surface: Colors.white,
          error: AppTheme.error,
          outline: border,
          outlineVariant: border,
        );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme
          .apply(bodyColor: primaryText, displayColor: primaryDarkGreen)
          .copyWith(
            headlineLarge: base.textTheme.headlineLarge?.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
              color: primaryDarkGreen,
            ),
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: primaryDarkGreen,
            ),
            headlineSmall: base.textTheme.headlineSmall?.copyWith(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.35,
              color: primaryDarkGreen,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: primaryText,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              height: 1.4,
              color: secondaryText,
            ),
          ),
      appBarTheme: const AppBarTheme(
        toolbarHeight: 64,
        backgroundColor: background,
        foregroundColor: primaryDarkGreen,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: primaryDarkGreen,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: const TextStyle(color: secondaryText),
        labelStyle: const TextStyle(color: secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryEmerald, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(side: BorderSide(color: border)),
        selectedColor: lightMint,
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: lightMint,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
