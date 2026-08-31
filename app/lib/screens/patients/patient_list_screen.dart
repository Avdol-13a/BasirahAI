import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/patient.dart';
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
      setState(() => _patients = (rows as List).map((r) => Patient.fromMap(r)).toList());
    } catch (e) {
      // ignore: avoid_print
      print('LOAD PATIENTS ERROR: $e');
      setState(() => _errorMessage = "Couldn't load patients. Check your connection and pull to retry.");
    }
  }

  Future<void> _addPatient() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PatientFormScreen()),
    );
    if (created == true) _loadPatients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _supabase.auth.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPatients,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPatient,
        icon: const Icon(Icons.person_add),
        label: const Text('New Patient'),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Center(child: Text(_errorMessage!, textAlign: TextAlign.center)),
        ],
      );
    }
    if (_patients == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_patients!.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Center(child: Text('No patients yet. Tap "New Patient" to add one.')),
        ],
      );
    }
    return ListView.separated(
      itemCount: _patients!.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final patient = _patients![i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(patient.name),
          subtitle: patient.gender != null ? Text(patient.gender!) : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: patient)),
          ),
        );
      },
    );
  }
}
