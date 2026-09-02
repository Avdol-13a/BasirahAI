import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/result_category.dart';
import '../../services/inference_service.dart';
import '../../theme/app_theme.dart';

class ResultScreen extends StatefulWidget {
  final String patientId;
  final ScreeningResult result;
  final String screeningId;

  const ResultScreen({
    super.key,
    required this.patientId,
    required this.result,
    required this.screeningId,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSaved = false;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _saveScreening();
  }

  Future<void> _saveScreening() async {
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      // upsert on the client-generated id (see ScreeningCaptureScreen,
      // generateUuidV4()) makes a retry after a failed/uncertain save
      // idempotent — re-sending the same id updates the same row instead
      // of risking a duplicate history entry.
      await Supabase.instance.client.from('screenings').upsert({
        'id': widget.screeningId,
        'patient_id': widget.patientId,
        'owner_user_id': userId,
        'referable': widget.result.referable,
        'confidence': widget.result.confidence,
        'raw_grade': widget.result.rawGrade,
        'raw_grade_label': widget.result.rawGradeLabel,
      }, onConflict: 'id');
      setState(() => _isSaved = true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _saveError = AppLocalizations.of(context).saveResultError,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  _ResultContent _contentFor(BuildContext context, ResultCategory category) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    switch (category) {
      case ResultCategory.nonReferable:
        return _ResultContent(
          icon: Icons.check_circle_outline,
          color: colors.success,
          badgeBg: colors.successSoft,
          headline: l10n.nonReferableHeadline,
          message: l10n.nonReferableMessage,
        );
      case ResultCategory.referable:
        return _ResultContent(
          icon: Icons.warning_amber_rounded,
          color: colors.danger,
          badgeBg: colors.dangerSoft,
          headline: l10n.referableHeadline,
          message: l10n.referableMessage,
        );
      case ResultCategory.lowConfidence:
        return _ResultContent(
          icon: Icons.help_outline,
          color: colors.neutral,
          badgeBg: colors.neutralSoft,
          headline: l10n.lowConfidenceHeadline,
          message: l10n.lowConfidenceMessage,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final category = ResultCategorizer.categorize(widget.result);
    final content = _contentFor(context, category);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resultTitle)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(26, 8, 26, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: content.badgeBg,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(content.icon, size: 38, color: content.color),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              content.headline,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              content.message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.inkMuted, height: 1.5),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: content.badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.confidencePercent(
                    (widget.result.confidence * 100).toStringAsFixed(0),
                  ),
                  style: TextStyle(
                    color: content.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                l10n.safetyDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.inkMuted,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_isSaving)
              Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
              )
            else if (_saveError != null) ...[
              Text(
                _saveError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.danger, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextButton(
                // Disabled while a save is in flight — guards against a
                // double tap re-firing an overlapping upsert.
                onPressed: _isSaving ? null : _saveScreening,
                child: Text(l10n.retrySaveButton),
              ),
            ] else if (_isSaved)
              Text(
                l10n.savedToHistory,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.inkFaint, fontSize: 12),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              // ScreeningCaptureScreen pushed this screen via pushReplacement,
              // so a single pop here returns straight to PatientDetailScreen.
              // Deliberately left enabled even while a save is in flight —
              // the screening result itself is already final and shown
              // regardless of save status, the save uses mounted-guarded
              // setState so leaving mid-save can't crash, and PatientDetail's
              // RouteAware reload (didPopNext) simply won't see this
              // particular row yet if the user leaves before it finishes.
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.doneButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultContent {
  final IconData icon;
  final Color color;
  final Color badgeBg;
  final String headline;
  final String message;

  _ResultContent({
    required this.icon,
    required this.color,
    required this.badgeBg,
    required this.headline,
    required this.message,
  });
}
