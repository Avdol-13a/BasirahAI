import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart' show routeObserver;
import '../../models/patient.dart';
import '../screening/screening_capture_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> with RouteAware {
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
      setState(() => _errorMessage = "Couldn't load screening history. Pull to retry.");
    }
  }

  Future<void> _newScreening() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScreeningCaptureScreen(patientId: widget.patient.id)),
    );
    _loadScreenings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.patient.name)),
      body: RefreshIndicator(
        onRefresh: _loadScreenings,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.patient.gender != null) Text('Gender: ${widget.patient.gender}'),
                    if (widget.patient.dateOfBirth != null)
                      Text('Date of birth: ${widget.patient.dateOfBirth!.toIso8601String().split('T').first}'),
                    if (widget.patient.phone != null) Text('Phone: ${widget.patient.phone}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _newScreening,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('New Screening'),
            ),
            const SizedBox(height: 24),
            Text('Screening History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red))
            else if (_screenings == null)
              const Center(child: CircularProgressIndicator())
            else if (_screenings!.isEmpty)
              const Text('No screenings yet.', style: TextStyle(color: Colors.black54))
            else
              ..._screenings!.map((s) {
                final referable = s['referable'] as bool;
                final confidence = (s['confidence'] as num).toDouble();
                final createdAt = DateTime.parse(s['created_at'] as String);
                return Card(
                  child: ListTile(
                    leading: Icon(
                      referable ? Icons.warning_amber_outlined : Icons.check_circle_outline,
                      color: referable ? Colors.deepOrange : Colors.green,
                    ),
                    title: Text(referable ? 'Referable' : 'Non-Referable'),
                    subtitle: Text(
                      '${createdAt.toLocal().toString().split('.').first} · Confidence ${(confidence * 100).toStringAsFixed(0)}%',
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
