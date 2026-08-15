// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Core brand - Blue accents
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color secondary = Color(0xFF38BDF8); // Sky Blue
  static const Color secondaryDark = Color(0xFF0284C7);

  // Backgrounds - Dark Theme
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceVariant = Color(0xFF334155);
  static const Color surfaceElevated = Color(0xFF475569);

  // Backgrounds - Light Theme
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9);
  static const Color surfaceElevatedLight = Color(0xFFE2E8F0);

  // Priority / severity
  static const Color critical = Color(0xFFFF3B30);
  static const Color high = Color(0xFFFF9500);
  static const Color medium = Color(0xFFFFCC02);
  static const Color low = Color(0xFF34C759);

  // Text - Dark Theme
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textHint = Color(0xFF64748B);

  // Text - Light Theme
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textHintLight = Color(0xFF94A3B8);

  // Borders / dividers - Dark
  static const Color border = Color(0xFF334155);
  static const Color cardBorder = Color(0xFF1E293B);
  static const Color divider = Color(0xFF1E293B);

  // Borders / dividers - Light
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color cardBorderLight = Color(0xFFF1F5F9);
  static const Color dividerLight = Color(0xFFF1F5F9);

  // Semantic
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFF9500);
  static const Color success = Color(0xFF34C759);
  static const Color info = Color(0xFF007AFF);

  // Shimmer
  static const Color shimmerBase = Color(0xFF1E293B);
  static const Color shimmerHighlight = Color(0xFF334155);
  static const Color shimmerBaseLight = Color(0xFFF1F5F9);
  static const Color shimmerHighlightLight = Color(0xFFFFFFFF);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    return _buildTheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.black,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      backgroundColor: AppColors.background,
      textPrimaryColor: AppColors.textPrimary,
      textSecondaryColor: AppColors.textSecondary,
      textHintColor: AppColors.textHint,
      borderColor: AppColors.border,
      cardBorderColor: AppColors.cardBorder,
      dividerColor: AppColors.divider,
      surfaceElevatedColor: AppColors.surfaceElevated,
    );
  }

  static ThemeData light() {
    return _buildTheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimaryLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
      backgroundColor: AppColors.backgroundLight,
      textPrimaryColor: AppColors.textPrimaryLight,
      textSecondaryColor: AppColors.textSecondaryLight,
      textHintColor: AppColors.textHintLight,
      borderColor: AppColors.borderLight,
      cardBorderColor: AppColors.cardBorderLight,
      dividerColor: AppColors.dividerLight,
      surfaceElevatedColor: AppColors.surfaceElevatedLight,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color error,
    required Color onError,
    required Color surface,
    required Color onSurface,
    required Color surfaceContainerHighest,
    required Color backgroundColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required Color textHintColor,
    required Color borderColor,
    required Color cardBorderColor,
    required Color dividerColor,
    required Color surfaceElevatedColor,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      error: error,
      onError: onError,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceContainerHighest,
    );

    final baseTheme = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final baseTextTheme = GoogleFonts.outfitTextTheme(baseTheme.textTheme);

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(color: textPrimaryColor, fontWeight: FontWeight.w700),
      displayMedium: baseTextTheme.displayMedium?.copyWith(color: textPrimaryColor, fontWeight: FontWeight.w700),
      displaySmall: baseTextTheme.displaySmall?.copyWith(color: textPrimaryColor, fontWeight: FontWeight.w600),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(color: textPrimaryColor, fontWeight: FontWeight.w700),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(color: textPrimaryColor, fontWeight: FontWeight.w600),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: textPrimaryColor, fontWeight: FontWeight.w600),
      titleLarge: baseTextTheme.titleLarge?.copyWith(color: textPrimaryColor, fontWeight: FontWeight.w600),
      titleMedium: baseTextTheme.titleMedium?.copyWith(color: textPrimaryColor, fontWeight: FontWeight.w500),
      titleSmall: baseTextTheme.titleSmall?.copyWith(color: textSecondaryColor, fontWeight: FontWeight.w500),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textPrimaryColor),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondaryColor),
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: textHintColor),
      labelLarge: baseTextTheme.labelLarge?.copyWith(color: textPrimaryColor, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      labelMedium: baseTextTheme.labelMedium?.copyWith(color: textSecondaryColor),
      labelSmall: baseTextTheme.labelSmall?.copyWith(color: textHintColor),
    );

    return baseTheme.copyWith(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimaryColor),
        iconTheme: IconThemeData(color: textPrimaryColor),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cardBorderColor, width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: surfaceContainerHighest,
          disabledForegroundColor: textHintColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: error, width: 2),
        ),
        hintStyle: GoogleFonts.outfit(color: textHintColor, fontSize: 14),
        labelStyle: GoogleFonts.outfit(color: textSecondaryColor),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Bottom navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textHintColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerHighest,
        selectedColor: primary.withOpacity(0.2),
        disabledColor: surfaceContainerHighest,
        labelStyle: GoogleFonts.outfit(color: textSecondaryColor, fontSize: 12),
        secondaryLabelStyle: GoogleFonts.outfit(color: primary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor),
        ),
        side: BorderSide(color: borderColor),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorderColor),
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
        contentTextStyle: GoogleFonts.outfit(
          fontSize: 14,
          color: textSecondaryColor,
        ),
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 4,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevatedColor,
        contentTextStyle: GoogleFonts.outfit(color: textPrimaryColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      // Progress indicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceContainerHighest,
        circularTrackColor: surfaceContainerHighest,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return textHintColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withOpacity(0.3);
          }
          return surfaceContainerHighest;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(onPrimary),
        side: BorderSide(color: borderColor, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // List tile
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: textSecondaryColor,
        textColor: textPrimaryColor,
      ),

      // Tab bar
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textHintColor,
        indicatorColor: primary,
        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 14),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }
}
