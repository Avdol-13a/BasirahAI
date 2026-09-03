// Regression for a real production bug (2026-09-03): the Non-Referable
// result copy read "No Urgent Concern Found" / "No signs of urgent concern
// were found", which is easy to misread as "no diabetic retinopathy" even
// though Non-Referable (grades 0-1) includes Mild NPDR, which *is* DR. See
// docs/MEDICAL_SAFETY.md's "Cross-cutting rules" and dev/HANDOFF.md.
//
// This test doesn't assert exact copy (that's expected to be tweaked) -- it
// asserts the specific property that must never regress: the Non-Referable
// message must not claim or imply DR is absent, and must say so explicitly.

import 'package:flutter_test/flutter_test.dart';
import 'package:basirah_app/l10n/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();

  test('nonReferable copy never claims diabetic retinopathy is absent', () {
    final headline = en.nonReferableHeadline.toLowerCase();
    final message = en.nonReferableMessage.toLowerCase();

    // Must not flatly claim "no DR" / "no retinopathy" / "all clear".
    expect(headline.contains('no diabetic retinopathy'), isFalse);
    expect(headline.contains('no dr'), isFalse);

    // Must explicitly clarify that DR is not ruled out.
    expect(
      message.contains('does not mean') || message.contains("doesn't mean"),
      isTrue,
      reason:
          'Non-Referable message must explicitly clarify it does not mean '
          'no diabetic retinopathy is present, not just describe the result.',
    );
  });

  test('referable copy still recommends seeing a professional', () {
    expect(
      en.referableMessage.toLowerCase().contains('professional'),
      isTrue,
    );
  });
}
