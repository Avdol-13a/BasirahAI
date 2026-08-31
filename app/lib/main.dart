import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env.dart';
import 'l10n/app_localizations.dart';
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

class BasirahApp extends StatefulWidget {
  const BasirahApp({super.key});

  /// Switches the whole app's language. Plain setState-based, matching
  /// this project's "no state-management package" convention — see the
  /// language-toggle button used across screens (theme/app_theme.dart).
  static void setLocale(BuildContext context, Locale locale) {
    context.findAncestorStateOfType<_BasirahAppState>()?._setLocale(locale);
  }

  @override
  State<BasirahApp> createState() => _BasirahAppState();
}

class _BasirahAppState extends State<BasirahApp> {
  Locale _locale = const Locale('en');

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BasirahAI',
      theme: AppTheme.themeData(),
      navigatorObservers: [routeObserver],
      locale: _locale,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
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
