import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart' show routeObserver;
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../../utils/gender_label.dart';
import '../screening/screening_capture_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with RouteAware {
  List<Map<String, dynamic>>? _screenings;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadScreenings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Fires when a route pushed on top of this screen is popped (or, per
  // ScreeningCaptureScreen's pushReplacement into ResultScreen, replaced
  // away) and this screen becomes visible again — the reliable point to
  // refresh, since the _newScreening() await below resolves too early.
  @override
  void didPopNext() {
    _loadScreenings();
  }

  Future<void> _loadScreenings() async {
    setState(() => _errorMessage = null);
    try {
      final rows = await Supabase.instance.client
          .from('screenings')
          .select()
          .eq('patient_id', widget.patient.id)
          .order('created_at', ascending: false);
      setState(() => _screenings = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _errorMessage = AppLocalizations.of(context).loadScreeningsError,
        );
      }
    }
  }

  Future<void> _newScreening() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScreeningCaptureScreen(patientId: widget.patient.id),
      ),
    );
    _loadScreenings();
  }

  Widget _infoRow(IconData icon, String text) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14.5, color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.patient.name)),
      body: RefreshIndicator(
        onRefresh: _loadScreenings,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.patient.gender != null)
                      _infoRow(
                        Icons.person_outline,
                        localizedGender(widget.patient.gender!, l10n),
                      ),
                    if (widget.patient.dateOfBirth != null)
                      _infoRow(
                        Icons.calendar_today_outlined,
                        l10n.dateOfBirthPrefixed(
                          widget.patient.dateOfBirth!
                              .toIso8601String()
                              .split('T')
                              .first,
                        ),
                      ),
                    if (widget.patient.phone != null)
                      _infoRow(Icons.call_outlined, widget.patient.phone!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            AccentButton(
              onPressed: _newScreening,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, size: 20),
                  const SizedBox(width: 10),
                  Text(l10n.newScreeningButton),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.screeningHistoryTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              Text(_errorMessage!, style: TextStyle(color: colors.danger))
            else if (_screenings == null)
              Center(child: CircularProgressIndicator(color: colors.primary))
            else if (_screenings!.isEmpty)
              Text(
                l10n.noScreeningsMessage,
                style: TextStyle(color: colors.inkMuted),
              )
            else
              ..._screenings!.map((s) {
                final referable = s['referable'] as bool;
                final confidence = (s['confidence'] as num).toDouble();
                final createdAt = DateTime.parse(s['created_at'] as String);
                final badgeBg = referable
                    ? colors.dangerSoft
                    : colors.successSoft;
                final badgeColor = referable ? colors.danger : colors.success;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              referable
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: badgeColor,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  referable
                                      ? l10n.referableLabel
                                      : l10n.nonReferableLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: colors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.screeningSubtitle(
                                    // LRM marks (U+200E) keep this LTR date/time string from
                                    // being visually reordered by the bidi algorithm when
                                    // embedded in RTL (Urdu) text — it contains an internal
                                    // space, which otherwise splits it into separately-
                                    // reordered runs.
                                    '‎${createdAt.toLocal().toString().split('.').first}‎',
                                    (confidence * 100).toStringAsFixed(0),
                                  ),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
