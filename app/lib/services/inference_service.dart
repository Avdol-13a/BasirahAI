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

/// Standard failure categories for calling the inference backend, so the UI
/// layer (which has a BuildContext, and localizes) picks the message —
/// see docs/MEDICAL_SAFETY.md / docs/IMAGE_PIPELINE.md for the wording
/// contract each category follows.
enum InferenceErrorCode { connection, slowConnection, serverStarting, serverError, generic }

/// Thrown for any failure calling the inference backend. [detail], when
/// present, is a specific, user-safe message the backend itself returned
/// (validation errors — bad file, too large, corrupt, etc.; see
/// backend/app/main.py) and is always in English, since the backend does
/// not localize — the UI falls back to [code]'s localized message otherwise.
class InferenceException implements Exception {
  final InferenceErrorCode code;
  final String? detail;
  InferenceException(this.code, {this.detail});
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
      throw _exceptionFor(e);
    }
  }

  InferenceException _exceptionFor(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        return InferenceException(InferenceErrorCode.connection);
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return InferenceException(InferenceErrorCode.slowConnection);
      case DioExceptionType.receiveTimeout:
        return InferenceException(InferenceErrorCode.serverStarting);
      case DioExceptionType.badResponse:
        final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
        return InferenceException(InferenceErrorCode.serverError, detail: detail is String ? detail : null);
      default:
        return InferenceException(InferenceErrorCode.generic);
    }
  }
}
