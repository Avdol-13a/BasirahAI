import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/inference_service.dart';
import '../../theme/app_theme.dart';
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
          builder: (_) => ResultScreen(patientId: widget.patientId, result: result),
        ),
      );
    } on InferenceException catch (e) {
      setState(() => _errorMessage = e.userMessage);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Screening')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.file(_selectedImage!, height: 240, width: double.infinity, fit: BoxFit.cover),
              )
            else
              Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Icon(Icons.remove_red_eye_outlined, size: 52, color: AppColors.inkFaint),
                ),
              ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
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
                  backgroundColor: AppColors.border,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Uploading and analyzing...', style: TextStyle(color: AppColors.inkMuted)),
              const SizedBox(height: 16),
            ],
            if (_errorMessage != null) ...[
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isUploading ? null : _analyze,
                child: const Text('Retry'),
              ),
            ],
            AccentButton(
              onPressed: (_selectedImage == null || _isUploading) ? null : _analyze,
              child: const Text('Analyze'),
            ),
          ],
        ),
      ),
    );
  }
}
