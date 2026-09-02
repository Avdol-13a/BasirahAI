import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _gender;
  DateTime? _dateOfBirth;
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('patients').insert({
        'owner_user_id': userId,
        'name': _nameController.text.trim(),
        'date_of_birth': _dateOfBirth?.toIso8601String().split('T').first,
        'gender': _gender,
        'cnic': _cnicController.text.trim().isEmpty
            ? null
            : _cnicController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(context).savePatientError,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newPatientButton)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.fullNameLabel,
                  prefixIcon: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: colors.inkMuted,
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.fullNameRequiredError
                    : null,
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDateOfBirth,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.dobLabel,
                    prefixIcon: Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: colors.inkMuted,
                    ),
                  ),
                  child: Text(
                    _dateOfBirth == null
                        ? l10n.dobNotSet
                        : '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: _dateOfBirth == null
                          ? colors.inkFaint
                          : colors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: InputDecoration(
                  labelText: l10n.genderLabel,
                  prefixIcon: Icon(
                    Icons.wc_outlined,
                    size: 20,
                    color: colors.inkMuted,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Female',
                    child: Text(l10n.genderFemale),
                  ),
                  DropdownMenuItem(value: 'Male', child: Text(l10n.genderMale)),
                  DropdownMenuItem(
                    value: 'Other',
                    child: Text(l10n.genderOther),
                  ),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cnicController,
                decoration: InputDecoration(
                  labelText: l10n.cnicLabel,
                  prefixIcon: Icon(
                    Icons.badge_outlined,
                    size: 20,
                    color: colors.inkMuted,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: l10n.phoneLabel,
                  prefixIcon: Icon(
                    Icons.call_outlined,
                    size: 20,
                    color: colors.inkMuted,
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 22),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: colors.danger),
                  ),
                ),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.savePatientButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
