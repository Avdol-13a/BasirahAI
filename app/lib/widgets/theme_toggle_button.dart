import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';

/// A small pill button (visually paired with LanguageToggleButton) that
/// opens a System / Light / Dark menu and switches the whole app's theme.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  IconData _iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  String _labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final current = BasirahApp.themeModeOf(context);

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme',
      initialValue: current,
      onSelected: (mode) => BasirahApp.setThemeMode(context, mode),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => ThemeMode.values
          .map(
            (mode) => PopupMenuItem(
              value: mode,
              child: Row(
                children: [
                  Icon(
                    _iconFor(mode),
                    size: 18,
                    color: mode == current ? colors.accent : colors.inkMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(_labelFor(mode)),
                  if (mode == current) ...[
                    const Spacer(),
                    Icon(Icons.check, size: 16, color: colors.accent),
                  ],
                ],
              ),
            ),
          )
          .toList(),
      child: Material(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(_iconFor(current), size: 18, color: colors.inkMuted),
        ),
      ),
    );
  }
}
