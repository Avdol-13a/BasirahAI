import '../services/inference_service.dart';

enum ResultCategory { nonReferable, referable, lowConfidence }

class ResultCategorizer {
  /// Starting value — tune once real evaluation data exists.
  /// See docs/ML_PLAN.md ("Low-confidence cutoff") and
  /// docs/EVALUATION_RESULTS.md — update both when this changes.
  static const double lowConfidenceCutoff = 0.6;

  static ResultCategory categorize(ScreeningResult result) {
    if (result.confidence < lowConfidenceCutoff) return ResultCategory.lowConfidence;
    return result.referable ? ResultCategory.referable : ResultCategory.nonReferable;
  }
}
