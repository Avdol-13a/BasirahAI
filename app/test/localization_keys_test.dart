// Verifies the new strings added for this hardening pass (image-suitability
// rejection messages, capture guidance, retry-save) exist and are non-empty
// in both supported locales -- catches an ARB key added to only one
// language file before it reaches a device.

import 'package:flutter_test/flutter_test.dart';
import 'package:basirah_app/l10n/app_localizations_en.dart';
import 'package:basirah_app/l10n/app_localizations_ur.dart';

void main() {
  final en = AppLocalizationsEn();
  final ur = AppLocalizationsUr();

  final getters = <String, String Function(dynamic)>{
    'captureGuidanceMessage': (l10n) => l10n.captureGuidanceMessage as String,
    'retrySaveButton': (l10n) => l10n.retrySaveButton as String,
    'imageBadAspectRatioMsg': (l10n) => l10n.imageBadAspectRatioMsg as String,
    'imageTooDarkMsg': (l10n) => l10n.imageTooDarkMsg as String,
    'imageTooBrightMsg': (l10n) => l10n.imageTooBrightMsg as String,
    'imageTooBlurryMsg': (l10n) => l10n.imageTooBlurryMsg as String,
    'imageNotFundusLikeMsg': (l10n) => l10n.imageNotFundusLikeMsg as String,
    'imageSoftFocusWarningMsg': (l10n) => l10n.imageSoftFocusWarningMsg as String,
    'imageNotFundusPhotoMsg': (l10n) => l10n.imageNotFundusPhotoMsg as String,
    'uncertainFundusContentWarningMsg': (l10n) => l10n.uncertainFundusContentWarningMsg as String,
  };

  for (final entry in getters.entries) {
    test('${entry.key} is present and non-empty in English', () {
      expect(entry.value(en).trim(), isNotEmpty);
    });
    test('${entry.key} is present and non-empty in Urdu', () {
      expect(entry.value(ur).trim(), isNotEmpty);
    });
  }
}
