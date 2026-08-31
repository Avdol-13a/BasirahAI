import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/result_category.dart';
import '../../services/inference_service.dart';
import '../../theme/app_theme.dart';

class ResultScreen extends StatefulWidget {
  final String patientId;
  final ScreeningResult result;

  const ResultScreen({super.key, required this.patientId, required this.result});

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
      await Supabase.instance.client.from('screenings').insert({
        'patient_id': widget.patientId,
        'owner_user_id': userId,
        'referable': widget.result.referable,
        'confidence': widget.result.confidence,
        'raw_grade': widget.result.rawGrade,
        'raw_grade_label': widget.result.rawGradeLabel,
      });
      setState(() => _isSaved = true);
    } catch (e) {
      setState(() => _saveError = "This result wasn't saved to history — check your connection. The screening itself is still valid.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  _ResultContent _contentFor(ResultCategory category) {
    switch (category) {
      case ResultCategory.nonReferable:
        return _ResultContent(
          icon: Icons.check_circle_outline,
          color: AppColors.success,
          badgeBg: AppColors.successSoft,
          headline: 'No Urgent Concern Found',
          message: 'No signs of urgent concern were found in this screening. This is not a '
              'diagnosis. Regular eye check-ups are still recommended, especially if the '
              'patient has diabetes.',
        );
      case ResultCategory.referable:
        return _ResultContent(
          icon: Icons.warning_amber_rounded,
          color: AppColors.danger,
          badgeBg: AppColors.dangerSoft,
          headline: 'Please See an Eye-Care Professional',
          message: 'This screening found signs that should be checked by an eye-care '
              'professional. Please arrange an ophthalmologist visit as soon as possible. '
              'This is not a diagnosis — only a specialist can confirm what this means.',
        );
      case ResultCategory.lowConfidence:
        return _ResultContent(
          icon: Icons.help_outline,
          color: AppColors.neutral,
          badgeBg: AppColors.neutralSoft,
          headline: 'Result Not Clear',
          message: 'This screening could not give a clear result. Please see an eye-care '
              'professional to be sure.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = ResultCategorizer.categorize(widget.result);
    final content = _contentFor(category);

    return Scaffold(
      appBar: AppBar(title: const Text('Screening Result')),
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
                decoration: BoxDecoration(color: content.badgeBg, borderRadius: BorderRadius.circular(28)),
                child: Icon(content.icon, size: 38, color: content.color),
              ),
            ),
            const SizedBox(height: 18),
            Text(content.headline, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(content.message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkMuted, height: 1.5)),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: content.badgeBg, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'Confidence: ${(widget.result.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: content.color, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(16)),
              child: const Text(
                'BasirahAI is a screening aid, not a diagnosis. It has not been clinically '
                'validated. Always follow up with a qualified eye-care professional.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            if (_isSaving)
              const Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
            else if (_saveError != null)
              Text(_saveError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 12))
            else if (_isSaved)
              const Text('Saved to patient history', textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkFaint, fontSize: 12)),
            const SizedBox(height: 24),
            ElevatedButton(
              // ScreeningCaptureScreen pushed this screen via pushReplacement,
              // so a single pop here returns straight to PatientDetailScreen.
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
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

  _ResultContent({required this.icon, required this.color, required this.badgeBg, required this.headline, required this.message});
}
