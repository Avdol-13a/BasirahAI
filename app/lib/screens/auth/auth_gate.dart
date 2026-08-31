import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../patients/patient_list_screen.dart';
import 'login_screen.dart';

/// Shows LoginScreen or the signed-in app shell depending on auth state,
/// and keeps them in sync as the user logs in/out.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const PatientListScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
