import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../theme/app_theme.dart';

/// A small pill button that switches the whole app's language. Shows the
/// *other* language's name (what tapping it switches to), so it needs no
/// separate "Language" label of its own.
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final targetLocale = isUrdu ? const Locale('en') : const Locale('ur');
    final label = isUrdu ? l10n.switchToEnglish : l10n.switchToUrdu;

    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => BasirahApp.setLocale(context, targetLocale),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate, size: 16, color: AppColors.inkMuted),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
