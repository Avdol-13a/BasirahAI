import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:basirah_app/services/inference_service.dart';

RequestOptions _requestOptions() => RequestOptions(path: '/screen');

DioException _badResponse(dynamic data, {int statusCode = 400}) {
  final options = _requestOptions();
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: statusCode, data: data),
  );
}

void main() {
  group('ScreeningResult.fromJson', () {
    test('parses a well-formed /screen response', () {
      final result = ScreeningResult.fromJson({
        'referable': true,
        'confidence': 0.87,
        'raw_grade': 3,
        'raw_grade_label': 'Severe',
        'class_probabilities': [0.01, 0.02, 0.1, 0.6, 0.27],
      });

      expect(result.referable, isTrue);
      expect(result.confidence, closeTo(0.87, 1e-9));
      expect(result.rawGrade, 3);
      expect(result.rawGradeLabel, 'Severe');
    });

    test('accepts an integer confidence (num, not just double)', () {
      final result = ScreeningResult.fromJson({
        'referable': false,
        'confidence': 1,
        'raw_grade': 0,
        'raw_grade_label': 'No DR',
      });
      expect(result.confidence, 1.0);
    });
  });

  group('mapDioExceptionToInferenceException', () {
    test('connectionError maps to connection', () {
      final e = mapDioExceptionToInferenceException(
        DioException(requestOptions: _requestOptions(), type: DioExceptionType.connectionError),
      );
      expect(e.code, InferenceErrorCode.connection);
    });

    test('connectionTimeout and sendTimeout map to slowConnection', () {
      for (final type in [DioExceptionType.connectionTimeout, DioExceptionType.sendTimeout]) {
        final e = mapDioExceptionToInferenceException(
          DioException(requestOptions: _requestOptions(), type: type),
        );
        expect(e.code, InferenceErrorCode.slowConnection);
      }
    });

    test('receiveTimeout maps to serverStarting', () {
      final e = mapDioExceptionToInferenceException(
        DioException(requestOptions: _requestOptions(), type: DioExceptionType.receiveTimeout),
      );
      expect(e.code, InferenceErrorCode.serverStarting);
    });

    test('badResponse with a plain string detail maps to serverError, detail preserved', () {
      final e = mapDioExceptionToInferenceException(
        _badResponse({'detail': 'Uploaded file is empty.'}),
      );
      expect(e.code, InferenceErrorCode.serverError);
      expect(e.detail, 'Uploaded file is empty.');
    });

    test('badResponse with a structured {code, message} detail maps to imageUnsuitable', () {
      final e = mapDioExceptionToInferenceException(
        _badResponse({
          'detail': {'code': 'too_blurry', 'message': 'This photo looks too blurry to analyze.'},
        }),
      );
      expect(e.code, InferenceErrorCode.imageUnsuitable);
      expect(e.imageIssueCode, 'too_blurry');
      expect(e.detail, 'This photo looks too blurry to analyze.');
    });

    test('badResponse with an unrecognized structured code still maps to imageUnsuitable', () {
      // Forward-compatible: a backend-only update adding a new check code
      // should not crash an older app build.
      final e = mapDioExceptionToInferenceException(
        _badResponse({
          'detail': {'code': 'some_future_check', 'message': 'A new kind of rejection.'},
        }),
      );
      expect(e.code, InferenceErrorCode.imageUnsuitable);
      expect(e.imageIssueCode, 'some_future_check');
    });

    test('badResponse with no body maps to serverError with no detail', () {
      final e = mapDioExceptionToInferenceException(_badResponse(null));
      expect(e.code, InferenceErrorCode.serverError);
      expect(e.detail, isNull);
    });

    test('any other DioException type maps to generic', () {
      final e = mapDioExceptionToInferenceException(
        DioException(requestOptions: _requestOptions(), type: DioExceptionType.cancel),
      );
      expect(e.code, InferenceErrorCode.generic);
    });
  });
}
