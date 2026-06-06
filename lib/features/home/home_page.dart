import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../article_reader/article_reader_page.dart';
import '../scenario_conversation/scenario_conversation_page.dart';
import '../speak_practice/speak_practice_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _TopBar(),
              const SizedBox(height: 16),
              _DateLabel(),
              const SizedBox(height: 12),
              _LessonCard(),
              const SizedBox(height: 24),
              _SecondLessonCard(),
              const SizedBox(height: 24),
              _ScenarioConversationCard(),
              const SizedBox(height: 24),
              _LockedCard(),
              const SizedBox(height: 24),
              _LockedCard(),
              const SizedBox(height: 24),
              _LockedCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: Color(0xFFFF2D55)),
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _StatChip(emoji: '🔥', value: 0, color: const Color(0xFFFF9500)),
          const SizedBox(width: 8),
          _StatChip(emoji: '💎', value: 0, color: const Color(0xFFFF2D55)),
          const SizedBox(width: 8),
          _StatChip(emoji: '⭐', value: 0, color: const Color(0xFFFFCC00)),
          const Spacer(),
          const Icon(
            Icons.emoji_events_outlined,
            color: Color(0xFFFF2D55),
            size: 28,
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.notifications_outlined,
            color: Color(0xFFFF2D55),
            size: 28,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _confirmSignOut(context),
            child: const Icon(
              Icons.logout,
              color: Color(0xFFFF2D55),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final int value;
  final Color color;

  const _StatChip({
    required this.emoji,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Today',
        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'First Lesson',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Let's begin your journey to fluency.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ArticleReaderPage()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Start Lesson'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondLessonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Second Lesson',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Practice speaking with live speech recognition.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SpeakPracticePage()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Start Speaking'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioConversationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conversation Scenario',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Practice a real restaurant conversation in German.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ScenarioConversationPage(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Start Scenario'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFDDE3EA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.lock, color: Color(0xFF9AA5B4), size: 32),
    );
  }
}
