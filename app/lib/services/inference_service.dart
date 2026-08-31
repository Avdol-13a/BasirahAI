import 'dart:io';
import 'package:dio/dio.dart';
import '../config/env.dart';

class ScreeningResult {
  final bool referable;
  final double confidence;
  final int rawGrade;
  final String rawGradeLabel;

  ScreeningResult({
    required this.referable,
    required this.confidence,
    required this.rawGrade,
    required this.rawGradeLabel,
  });

  factory ScreeningResult.fromJson(Map<String, dynamic> json) {
    return ScreeningResult(
      referable: json['referable'] as bool,
      confidence: (json['confidence'] as num).toDouble(),
      rawGrade: json['raw_grade'] as int,
      rawGradeLabel: json['raw_grade_label'] as String,
    );
  }
}

/// Thrown for any failure calling the inference backend. [userMessage] is
/// always safe to show directly in the UI (see docs/MEDICAL_SAFETY.md /
/// docs/IMAGE_PIPELINE.md for the wording contract this follows).
class InferenceException implements Exception {
  final String userMessage;
  InferenceException(this.userMessage);
}

class InferenceService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: Env.backendBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    // Inference itself is fast once the model is warm, but a cold-started
    // backend (first request after idle) can take a while to load the
    // model — see docs/ML_PLAN.md. Give it real room before giving up.
    receiveTimeout: const Duration(seconds: 60),
  ));

  Future<ScreeningResult> screen(File imageFile, {void Function(double progress)? onProgress}) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imageFile.path, filename: 'photo.jpg'),
      });

      final response = await _dio.post(
        '/screen',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );

      return ScreeningResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw InferenceException(_messageFor(e));
    }
  }

  String _messageFor(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        return "Couldn't reach the server. Check your internet connection and try again.";
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return 'The connection is too slow right now. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'The server is taking too long to respond (it may be starting up after being idle). Please try again in a moment.';
      case DioExceptionType.badResponse:
        // The backend returns a specific, user-safe message in `detail` for
        // validation errors (bad file, too large, corrupt, etc.) — see
        // backend/app/main.py and docs/IMAGE_PIPELINE.md.
        final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
        return detail is String ? detail : 'Something went wrong on the server. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
