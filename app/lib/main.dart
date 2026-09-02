import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'l10n/app_localizations.dart';
import 'screens/auth/auth_gate.dart';
import 'theme/app_theme.dart';

/// SharedPreferences key for the persisted theme-mode choice ('system' /
/// 'light' / 'dark'). The language toggle deliberately stays in-memory-only
/// (see LanguageToggleButton) to avoid a native-asset build risk that hit a
/// different plugin on this project's Windows dev machine — shared_preferences
/// itself was already pulled in transitively (verified before adding it as a
/// direct dependency) and a real debug build was confirmed to still succeed,
/// so persisting the theme choice doesn't carry that same risk.
const _themeModePrefsKey = 'theme_mode';

ThemeMode _themeModeFromString(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String _themeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

/// Lets a screen (e.g. PatientDetailScreen) know when it's been revealed
/// again after a pushed route above it was popped OR replaced away —
/// needed because ScreeningCaptureScreen uses pushReplacement for
/// ResultScreen, which resolves an awaited Navigator.push before the
/// user actually finishes there. See PatientDetailScreen's RouteAware use.
final routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.isSupabaseConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
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

  /// Switches the whole app's theme mode (system/light/dark) and persists
  /// the choice — see ThemeToggleButton (widgets/theme_toggle_button.dart).
  static void setThemeMode(BuildContext context, ThemeMode mode) {
    context.findAncestorStateOfType<_BasirahAppState>()?._setThemeMode(mode);
  }

  /// Current theme mode, so the toggle button can show which option is
  /// active without holding its own state.
  static ThemeMode themeModeOf(BuildContext context) {
    return context.findAncestorStateOfType<_BasirahAppState>()?._themeMode ??
        ThemeMode.system;
  }

  @override
  State<BasirahApp> createState() => _BasirahAppState();
}

class _BasirahAppState extends State<BasirahApp> {
  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeModePrefsKey);
    if (stored != null && mounted) {
      setState(() => _themeMode = _themeModeFromString(stored));
    }
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_themeModePrefsKey, _themeModeToString(mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BasirahAI',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,
      navigatorObservers: [routeObserver],
      locale: _locale,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Env.isSupabaseConfigured
          ? const AuthGate()
          : const _MissingConfigScreen(),
    );
  }
}

/// Shown instead of crashing when the app is launched without
/// --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// See lib/config/env.dart and dev/plan.md.
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
