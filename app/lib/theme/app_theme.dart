import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

/// BasirahAI's "Warm Earth & Trust" design tokens — see the approved
/// design canvas (design conversation, 2026-08-31) for the source light
/// mockup; the dark palette (added for the theme-selector feature) keeps
/// the same warm-toned identity (warm near-black surfaces, not blue-black)
/// and the same semantic badge-bg/on-badge pairing per state, just with
/// luminance inverted appropriately for a dark background.
///
/// A [ThemeExtension] rather than static constants so every screen's
/// existing `AppColors.of(context).xxx` calls automatically resolve to the
/// right palette for the active [ThemeData] — this is what makes dark mode
/// work everywhere without each screen needing its own light/dark branching.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color border;

  final Color primary;
  final Color primaryDark;
  final Color primaryInk;

  final Color accent;
  final Color accentInk;
  final Color accentSoft;
  final Color accentSoftInk;

  final Color success;
  final Color successSoft;
  final Color successSoftInk;

  final Color danger;
  final Color dangerSoft;
  final Color dangerSoftInk;

  final Color neutral;
  final Color neutralSoft;
  final Color neutralSoftInk;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.border,
    required this.primary,
    required this.primaryDark,
    required this.primaryInk,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.accentSoftInk,
    required this.success,
    required this.successSoft,
    required this.successSoftInk,
    required this.danger,
    required this.dangerSoft,
    required this.dangerSoftInk,
    required this.neutral,
    required this.neutralSoft,
    required this.neutralSoftInk,
  });

  /// Shorthand for `Theme.of(context).extension<AppColors>()!` — every
  /// screen reads its colors through this instead of a static palette.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  static const light = AppColors(
    bg: Color(0xFFFAF7F2),
    surface: Color(0xFFFDFBF8),
    surfaceAlt: Color(0xFFF0EBE3),
    ink: Color(0xFF262220),
    inkMuted: Color(0xFF6B6560),
    inkFaint: Color(0xFF9C948C),
    border: Color(0xFFE3DCD2),
    primary: Color(0xFF1E2A5E),
    primaryDark: Color(0xFF17214A),
    primaryInk: Color(0xFFFBF9F6),
    accent: Color(0xFFC16A3C),
    accentInk: Color(0xFFFFF8F2),
    accentSoft: Color(0xFFF3DFCF),
    accentSoftInk: Color(0xFF8B4B26),
    success: Color(0xFF3D7852),
    successSoft: Color(0xFFDDEEDF),
    successSoftInk: Color(0xFF2C5E3D),
    danger: Color(0xFFC13F26),
    dangerSoft: Color(0xFFF6DAD2),
    dangerSoftInk: Color(0xFF8A2D18),
    neutral: Color(0xFF5B6478),
    neutralSoft: Color(0xFFE4E7EE),
    neutralSoftInk: Color(0xFF3E4657),
  );

  static const dark = AppColors(
    bg: Color(0xFF17140F),
    surface: Color(0xFF211D17),
    surfaceAlt: Color(0xFF2A2419),
    ink: Color(0xFFF3ECE3),
    inkMuted: Color(0xFFB7AC9D),
    inkFaint: Color(0xFF877D6E),
    border: Color(0xFF3C352A),
    primary: Color(0xFF5064AC),
    primaryDark: Color(0xFF3A4A8C),
    primaryInk: Color(0xFFFFFFFF),
    accent: Color(0xFFD98A56),
    accentInk: Color(0xFF3D2410),
    accentSoft: Color(0xFF3D2C1C),
    accentSoftInk: Color(0xFFF0C9A0),
    success: Color(0xFF6FBF8B),
    successSoft: Color(0xFF1E3226),
    successSoftInk: Color(0xFF8FE0AC),
    danger: Color(0xFFE8654A),
    dangerSoft: Color(0xFF3A1810),
    dangerSoftInk: Color(0xFFF0A18C),
    neutral: Color(0xFF8B96AE),
    neutralSoft: Color(0xFF262B38),
    neutralSoftInk: Color(0xFFB8C0D6),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? border,
    Color? primary,
    Color? primaryDark,
    Color? primaryInk,
    Color? accent,
    Color? accentInk,
    Color? accentSoft,
    Color? accentSoftInk,
    Color? success,
    Color? successSoft,
    Color? successSoftInk,
    Color? danger,
    Color? dangerSoft,
    Color? dangerSoftInk,
    Color? neutral,
    Color? neutralSoft,
    Color? neutralSoftInk,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryInk: primaryInk ?? this.primaryInk,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      accentSoft: accentSoft ?? this.accentSoft,
      accentSoftInk: accentSoftInk ?? this.accentSoftInk,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      successSoftInk: successSoftInk ?? this.successSoftInk,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerSoftInk: dangerSoftInk ?? this.dangerSoftInk,
      neutral: neutral ?? this.neutral,
      neutralSoft: neutralSoft ?? this.neutralSoft,
      neutralSoftInk: neutralSoftInk ?? this.neutralSoftInk,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      inkFaint: l(inkFaint, other.inkFaint),
      border: l(border, other.border),
      primary: l(primary, other.primary),
      primaryDark: l(primaryDark, other.primaryDark),
      primaryInk: l(primaryInk, other.primaryInk),
      accent: l(accent, other.accent),
      accentInk: l(accentInk, other.accentInk),
      accentSoft: l(accentSoft, other.accentSoft),
      accentSoftInk: l(accentSoftInk, other.accentSoftInk),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      successSoftInk: l(successSoftInk, other.successSoftInk),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      dangerSoftInk: l(dangerSoftInk, other.dangerSoftInk),
      neutral: l(neutral, other.neutral),
      neutralSoft: l(neutralSoft, other.neutralSoft),
      neutralSoftInk: l(neutralSoftInk, other.neutralSoftInk),
    );
  }
}

class AppTheme {
  AppTheme._();

  static const fontDisplay = 'Lora';
  static const fontBody = 'Manrope';

  static ThemeData lightTheme() =>
      _themeData(Brightness.light, AppColors.light);
  static ThemeData darkTheme() => _themeData(Brightness.dark, AppColors.dark);

  static ThemeData _themeData(Brightness brightness, AppColors colors) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.primaryInk,
      secondary: colors.accent,
      onSecondary: colors.accentInk,
      secondaryContainer: colors.accentSoft,
      onSecondaryContainer: colors.accentSoftInk,
      error: colors.danger,
      onError: isDark ? colors.dangerSoft : Colors.white,
      errorContainer: colors.dangerSoft,
      onErrorContainer: colors.dangerSoftInk,
      surface: colors.surface,
      onSurface: colors.ink,
      surfaceContainerHighest: colors.surfaceAlt,
      onSurfaceVariant: colors.inkMuted,
      outline: colors.border,
      outlineVariant: colors.border,
    );

    final textTheme = TextTheme(
      headlineMedium: TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w600,
        fontSize: 28,
        color: isDark ? colors.ink : colors.primary,
        letterSpacing: -0.2,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: colors.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w600,
        fontSize: 19,
        color: colors.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w600,
        fontSize: 17,
        color: colors.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontBody,
        fontSize: 15.5,
        color: colors.ink,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontBody,
        fontSize: 14.5,
        color: colors.ink,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: fontBody,
        fontSize: 13,
        color: colors.inkMuted,
        height: 1.4,
      ),
      labelLarge: const TextStyle(
        fontFamily: fontBody,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      labelMedium: TextStyle(
        fontFamily: fontBody,
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: colors.inkMuted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.bg,
      fontFamily: fontBody,
      textTheme: textTheme,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colors.ink),
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.primaryInk,
          disabledBackgroundColor: colors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: colors.primaryInk.withValues(alpha: 0.7),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.border, width: 1.5),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: fontBody,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          textStyle: const TextStyle(
            fontFamily: fontBody,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(
          fontFamily: fontBody,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: colors.inkMuted,
        ),
        hintStyle: TextStyle(fontFamily: fontBody, color: colors.inkFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.danger, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: colors.border, space: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: colors.accentInk,
        extendedTextStyle: const TextStyle(
          fontFamily: fontBody,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primaryInk,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.ink,
        contentTextStyle: TextStyle(
          fontFamily: fontBody,
          color: colors.bg,
          fontSize: 14,
        ),
        actionTextColor: colors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceAlt,
        labelStyle: TextStyle(
          fontFamily: fontBody,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: colors.inkMuted,
        ),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.accentSoft,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.accentSoftInk
                : colors.inkMuted,
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.border),
        ),
        textStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 14,
          color: colors.ink,
        ),
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
    final colors = AppColors.of(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: colors.accentInk,
        disabledBackgroundColor: colors.accent.withValues(alpha: 0.4),
        disabledForegroundColor: colors.accentInk.withValues(alpha: 0.7),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontBody,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        elevation: 0,
      ),
      child: child,
    );
  }
}
