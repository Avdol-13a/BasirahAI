import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env.dart';
import 'screens/auth/auth_gate.dart';
import 'theme/app_theme.dart';

/// Lets a screen (e.g. PatientDetailScreen) know when it's been revealed
/// again after a pushed route above it was popped OR replaced away —
/// needed because ScreeningCaptureScreen uses pushReplacement for
/// ResultScreen, which resolves an awaited Navigator.push before the
/// user actually finishes there. See PatientDetailScreen's RouteAware use.
final routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.isSupabaseConfigured) {
    await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  }

  runApp(const BasirahApp());
}

class BasirahApp extends StatelessWidget {
  const BasirahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BasirahAI',
      theme: AppTheme.themeData(),
      navigatorObservers: [routeObserver],
      home: Env.isSupabaseConfigured ? const AuthGate() : const _MissingConfigScreen(),
    );
  }
}

/// Shown instead of crashing when the app is launched without
/// --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// See lib/config/env.dart and plan.md.
class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Supabase isn\'t configured yet.\n\n'
            'Run with:\n'
            'flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...\n\n'
            'See lib/config/env.dart.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
