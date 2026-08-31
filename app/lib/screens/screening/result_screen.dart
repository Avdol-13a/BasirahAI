import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/result_category.dart';
import '../../services/inference_service.dart';

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
          color: Colors.green,
          headline: 'No Urgent Concern Found',
          message: 'No signs of urgent concern were found in this screening. This is not a '
              'diagnosis. Regular eye check-ups are still recommended, especially if the '
              'patient has diabetes.',
        );
      case ResultCategory.referable:
        return _ResultContent(
          icon: Icons.warning_amber_outlined,
          color: Colors.deepOrange,
          headline: 'Please See an Eye-Care Professional',
          message: 'This screening found signs that should be checked by an eye-care '
              'professional. Please arrange an ophthalmologist visit as soon as possible. '
              'This is not a diagnosis — only a specialist can confirm what this means.',
        );
      case ResultCategory.lowConfidence:
        return _ResultContent(
          icon: Icons.help_outline,
          color: Colors.blueGrey,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(content.icon, size: 72, color: content.color),
            const SizedBox(height: 16),
            Text(content.headline, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(content.message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Confidence: ${(widget.result.confidence * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'BasirahAI is a screening aid, not a diagnosis. It has not been clinically '
                'validated. Always follow up with a qualified eye-care professional.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 12),
            if (_isSaving)
              const Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_saveError != null)
              Text(_saveError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 12))
            else if (_isSaved)
              const Text('Saved to patient history', textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontSize: 12)),
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
  final String headline;
  final String message;

  _ResultContent({required this.icon, required this.color, required this.headline, required this.message});
}
