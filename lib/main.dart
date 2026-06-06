import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/welcome/welcome_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gfdsibvelqceexcgerah.supabase.co',
    anonKey: 'sb_publishable_vFZdq8NT56-4deP4eH3xOQ_SQQ4GBW2',
  );

  runApp(const ContextApp());
}

class ContextApp extends StatelessWidget {
  const ContextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Context',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFEFF3F7)),
      home: const _RootPage(),
    );
  }
}

class _RootPage extends StatefulWidget {
  const _RootPage();

  @override
  State<_RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<_RootPage> {
  late final StreamSubscription<AuthState> _authSub;
  Session? _session;
  bool _checkingProfile = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final newSession = data.session;

      setState(() {
        _session = newSession;
        if (newSession == null) {
          _checkingProfile = false;
          _showOnboarding = false;
        }
      });

      // Check the profile both on a fresh sign-in and on app restart
      // (initialSession), so onboarding can resume if it was interrupted.
      if (newSession != null &&
          (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.initialSession)) {
        _checkProfile();
      }
    });
  }

  Future<void> _checkProfile() async {
    setState(() => _checkingProfile = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final result = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (mounted) setState(() => _showOnboarding = result == null);
    } catch (_) {
      if (mounted) setState(() => _showOnboarding = false);
    } finally {
      if (mounted) setState(() => _checkingProfile = false);
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) return const WelcomePage();

    if (_checkingProfile) {
      return const Scaffold(
        backgroundColor: Color(0xFFEFF3F7),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    if (_showOnboarding) {
      return OnboardingFlow(
        onComplete: () => setState(() => _showOnboarding = false),
      );
    }

    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    Placeholder(),
    Placeholder(),
    Placeholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Practice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Leagues',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
