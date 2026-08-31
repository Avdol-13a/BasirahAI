import 'package:flutter/material.dart';

/// BasirahAI's "Warm Earth & Trust" design tokens — see the approved
/// design canvas (design conversation, 2026-08-31) for the source mockup.
/// Deep indigo for navigation/auth/save actions, warm terracotta reserved
/// for the screening-specific calls to action (New Screening, Analyze),
/// and a distinct sage/vermillion/cool-gray per screening result state.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFFAF7F2);
  static const surface = Color(0xFFFDFBF8);
  static const surfaceAlt = Color(0xFFF0EBE3);
  static const ink = Color(0xFF262220);
  static const inkMuted = Color(0xFF6B6560);
  static const inkFaint = Color(0xFF9C948C);
  static const border = Color(0xFFE3DCD2);

  static const primary = Color(0xFF1E2A5E);
  static const primaryDark = Color(0xFF17214A);
  static const primaryInk = Color(0xFFFBF9F6);

  static const accent = Color(0xFFC16A3C);
  static const accentInk = Color(0xFFFFF8F2);
  static const accentSoft = Color(0xFFF3DFCF);
  static const accentSoftInk = Color(0xFF8B4B26);

  static const success = Color(0xFF3D7852);
  static const successSoft = Color(0xFFDDEEDF);
  static const successSoftInk = Color(0xFF2C5E3D);

  static const danger = Color(0xFFC13F26);
  static const dangerSoft = Color(0xFFF6DAD2);
  static const dangerSoftInk = Color(0xFF8A2D18);

  static const neutral = Color(0xFF5B6478);
  static const neutralSoft = Color(0xFFE4E7EE);
  static const neutralSoftInk = Color(0xFF3E4657);
}

class AppTheme {
  AppTheme._();

  static const fontDisplay = 'Lora';
  static const fontBody = 'Manrope';

  static ThemeData themeData() {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryInk,
      secondary: AppColors.accent,
      onSecondary: AppColors.accentInk,
      secondaryContainer: AppColors.accentSoft,
      onSecondaryContainer: AppColors.accentSoftInk,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerSoft,
      onErrorContainer: AppColors.dangerSoftInk,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      outline: AppColors.border,
    );

    final textTheme = TextTheme(
      headlineMedium: const TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w600,
        fontSize: 28,
        color: AppColors.primary,
        letterSpacing: -0.2,
      ),
      headlineSmall: const TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: AppColors.ink,
      ),
      titleLarge: const TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w600,
        fontSize: 19,
        color: AppColors.ink,
      ),
      titleMedium: const TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w600,
        fontSize: 17,
        color: AppColors.ink,
      ),
      bodyLarge: const TextStyle(fontFamily: fontBody, fontSize: 15.5, color: AppColors.ink, height: 1.5),
      bodyMedium: const TextStyle(fontFamily: fontBody, fontSize: 14.5, color: AppColors.ink, height: 1.5),
      bodySmall: TextStyle(fontFamily: fontBody, fontSize: 13, color: AppColors.inkMuted, height: 1.4),
      labelLarge: const TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w700, fontSize: 16),
      labelMedium: const TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.inkMuted),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: fontBody,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.ink),
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryInk,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.primaryInk.withValues(alpha: 0.7),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.inkMuted),
        hintStyle: const TextStyle(fontFamily: fontBody, color: AppColors.inkFaint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.danger, width: 2)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border, width: 1)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentInk,
        extendedTextStyle: TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w700, fontSize: 15),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primaryInk),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

/// A pill-shaped, terracotta-accent button for the app's core screening
/// actions (New Screening, Analyze) — kept visually distinct from the
/// indigo [ElevatedButton] default used for navigation/auth/save actions.
class AccentButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const AccentButton({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentInk,
        disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
        disabledForegroundColor: AppColors.accentInk.withValues(alpha: 0.7),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: AppTheme.fontBody, fontWeight: FontWeight.w700, fontSize: 16),
        elevation: 0,
      ),
      child: child,
    );
  }
}
