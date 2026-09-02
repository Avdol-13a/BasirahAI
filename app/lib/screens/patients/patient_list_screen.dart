import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../../utils/gender_label.dart';
import '../../widgets/language_toggle_button.dart';
import '../../widgets/theme_toggle_button.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _supabase = Supabase.instance.client;

  List<Patient>? _patients;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _errorMessage = null);
    try {
      final rows = await _supabase
          .from('patients')
          .select()
          .order('created_at', ascending: false);
      setState(
        () =>
            _patients = (rows as List).map((r) => Patient.fromMap(r)).toList(),
      );
    } catch (e) {
      // ignore: avoid_print
      print('LOAD PATIENTS ERROR: $e');
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(context).loadPatientsError,
        );
      }
    }
  }

  Future<void> _addPatient() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PatientFormScreen()));
    if (created == true) _loadPatients();
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.patientsTitle,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontSize: 26),
        ),
        actions: [
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 4),
            child: ThemeToggleButton(),
          ),
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 4),
            child: LanguageToggleButton(),
          ),
          IconButton(
            icon: Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: const Icon(Icons.logout),
            ),
            color: AppColors.of(context).inkMuted,
            tooltip: l10n.logOutTooltip,
            onPressed: () => _supabase.auth.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPatients,
        child: _buildBody(context, l10n),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPatient,
        icon: const Icon(Icons.add),
        label: Text(l10n.newPatientButton),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final colors = AppColors.of(context);
    if (_errorMessage != null) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.wifi_off, size: 48, color: colors.inkFaint),
          const SizedBox(height: 14),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.inkMuted),
              ),
            ),
          ),
        ],
      );
    }
    if (_patients == null) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }
    if (_patients!.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.people_outline, size: 48, color: colors.inkFaint),
          const SizedBox(height: 14),
          Center(
            child: Text(
              l10n.noPatientsMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.inkMuted),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _patients!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final patient = _patients![i];
        return Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PatientDetailScreen(patient: patient),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _initialsFor(patient.name),
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: colors.accentSoftInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          patient.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            color: colors.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (patient.gender != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            localizedGender(patient.gender!, l10n),
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Transform.flip(
                    flipX: Directionality.of(context) == TextDirection.rtl,
                    child: Icon(Icons.chevron_right, color: colors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
