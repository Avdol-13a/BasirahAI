import '../l10n/app_localizations.dart';

/// Patient gender is stored in Supabase as one of the fixed English values
/// written by [PatientFormScreen]'s dropdown ('Female'/'Male'/'Other') —
/// this maps that raw stored value to its localized display label.
String localizedGender(String raw, AppLocalizations l10n) {
  switch (raw) {
    case 'Female':
      return l10n.genderFemale;
    case 'Male':
      return l10n.genderMale;
    default:
      return l10n.genderOther;
  }
}
