import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'state/memory_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    runApp(const _SetupErrorApp());
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey, // publishable key ONLY
  );
  runApp(const MemoriesApp());
}

class MemoriesApp extends StatelessWidget {
  const MemoriesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memories',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const RootGate(),
    );
  }
}

/// Splash -> (onboarding once) -> login/signup -> app.
/// Also listens to auth changes to clear cached data on logout.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  static const _seenKey = 'seen_onboarding';

  bool _ready = false;
  bool _seenOnboarding = false;
  bool _startInSignUp = false;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _boot();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        memoryStore.clear();
        StorageService.clearCache();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      Future<void>.delayed(const Duration(milliseconds: 1400)),
    ]);
    final prefs = results.first as SharedPreferences;
    if (!mounted) return;
    setState(() {
      _seenOnboarding = prefs.getBool(_seenKey) ?? false;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding(bool signUp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    if (!mounted) return;
    setState(() {
      _seenOnboarding = true;
      _startInSignUp = signUp;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SplashScreen();

    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        if (session != null) return const HomeShell();
        if (!_seenOnboarding) {
          return OnboardingScreen(onDone: _finishOnboarding);
        }
        return AuthScreen(initialSignUp: _startInSignUp);
      },
    );
  }
}

/// Friendly screen if you forgot to paste your Supabase values.
class _SetupErrorApp extends StatelessWidget {
  const _SetupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Center(
              child: Text(
                'Supabase is not configured.\n\nOpen lib/config/supabase_config.dart and replace <YOUR_SUPABASE_URL> and <YOUR_SUPABASE_PUBLISHABLE_KEY> with your project values, then rebuild.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
