import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../services/inference_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/uuid.dart';
import 'result_screen.dart';

class ScreeningCaptureScreen extends StatefulWidget {
  final String patientId;

  const ScreeningCaptureScreen({super.key, required this.patientId});

  @override
  State<ScreeningCaptureScreen> createState() => _ScreeningCaptureScreenState();
}

class _ScreeningCaptureScreenState extends State<ScreeningCaptureScreen> {
  final _picker = ImagePicker();
  final _inferenceService = InferenceService();

  File? _selectedImage;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _errorMessage;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    setState(() {
      _selectedImage = File(picked.path);
      _errorMessage = null;
    });
  }

  Future<void> _analyze() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _errorMessage = null;
    });

    try {
      final result = await _inferenceService.screen(
        _selectedImage!,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            patientId: widget.patientId,
            result: result,
            screeningId: generateUuidV4(),
          ),
        ),
      );
    } on InferenceException catch (e) {
      if (mounted) setState(() => _errorMessage = _messageFor(context, e));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _messageFor(BuildContext context, InferenceException e) {
    final l10n = AppLocalizations.of(context);
    switch (e.code) {
      case InferenceErrorCode.connection:
        return l10n.connectionErrorMsg;
      case InferenceErrorCode.slowConnection:
        return l10n.slowConnectionMsg;
      case InferenceErrorCode.serverStarting:
        return l10n.serverStartingMsg;
      case InferenceErrorCode.serverError:
        // The backend's own `detail` message is always English (see
        // InferenceException docs) — shown as-is when present.
        return e.detail ?? l10n.serverErrorMsg;
      case InferenceErrorCode.imageUnsuitable:
        // Localize by the backend's stable code when recognized, so a
        // future backend-only check doesn't need an app update to read
        // sensibly — an unknown code falls back to the backend's own
        // (English) message, then a generic one.
        return _imageIssueMessage(l10n, e.imageIssueCode) ??
            e.detail ??
            l10n.serverErrorMsg;
      case InferenceErrorCode.generic:
        return l10n.genericInferenceErrorMsg;
    }
  }

  String? _imageIssueMessage(AppLocalizations l10n, String? code) {
    switch (code) {
      case 'bad_aspect_ratio':
        return l10n.imageBadAspectRatioMsg;
      case 'too_dark':
        return l10n.imageTooDarkMsg;
      case 'too_bright':
        return l10n.imageTooBrightMsg;
      case 'too_blurry':
        return l10n.imageTooBlurryMsg;
      case 'not_fundus_like':
        return l10n.imageNotFundusLikeMsg;
      case 'not_fundus_photo':
        return l10n.imageNotFundusPhotoMsg;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newScreeningButton)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.captureGuidanceMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.inkMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.file(
                  _selectedImage!,
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.border),
                ),
                child: Center(
                  child: Icon(
                    Icons.remove_red_eye_outlined,
                    size: 52,
                    color: colors.inkFaint,
                  ),
                ),
              ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(l10n.cameraButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(l10n.galleryButton),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isUploading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  backgroundColor: colors.border,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.uploadingMessage,
                style: TextStyle(color: colors.inkMuted),
              ),
              const SizedBox(height: 16),
            ],
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.danger),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isUploading ? null : _analyze,
                child: Text(l10n.retryButton),
              ),
            ],
            AccentButton(
              onPressed: (_selectedImage == null || _isUploading)
                  ? null
                  : _analyze,
              child: Text(l10n.analyzeButton),
            ),
          ],
        ),
      ),
    );
  }
}
