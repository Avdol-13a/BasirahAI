import 'package:flutter_test/flutter_test.dart';
import 'package:basirah_app/models/result_category.dart';
import 'package:basirah_app/services/inference_service.dart';

ScreeningResult _result({required bool referable, required double confidence}) {
  return ScreeningResult(
    referable: referable,
    confidence: confidence,
    rawGrade: referable ? 3 : 0,
    rawGradeLabel: referable ? 'Severe' : 'No DR',
  );
}

void main() {
  group('ResultCategorizer', () {
    test('confident referable result categorizes as referable', () {
      final category = ResultCategorizer.categorize(_result(referable: true, confidence: 0.9));
      expect(category, ResultCategory.referable);
    });

    test('confident non-referable result categorizes as non-referable', () {
      final category = ResultCategorizer.categorize(_result(referable: false, confidence: 0.9));
      expect(category, ResultCategory.nonReferable);
    });

    test('confidence exactly at the cutoff is NOT low-confidence (boundary is exclusive)', () {
      final category = ResultCategorizer.categorize(
        _result(referable: true, confidence: ResultCategorizer.lowConfidenceCutoff),
      );
      expect(category, ResultCategory.referable);
    });

    test('confidence just below the cutoff is low-confidence regardless of referable', () {
      const justBelow = ResultCategorizer.lowConfidenceCutoff - 0.001;
      expect(
        ResultCategorizer.categorize(_result(referable: true, confidence: justBelow)),
        ResultCategory.lowConfidence,
      );
      expect(
        ResultCategorizer.categorize(_result(referable: false, confidence: justBelow)),
        ResultCategory.lowConfidence,
      );
    });
  });
}
